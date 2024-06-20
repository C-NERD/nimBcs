#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
{.experimental: "codeReordering".}

from std / strutils import parseHexStr, fromHex
from std / options import Option, none, get, some
from std / tables import CountTable, CountTableRef, OrderedTable,
        OrderedTableRef, Table, TableRef, `[]=`
from std / typetraits import genericParams, tupleLen, get
from std / bitops import bitand, bitor
import constants, largeints, hex

export fromHex, genericParams, get

const Is64Bit*: bool = block:

    var is64: bool = false
    if high(int) == high(int64):

        is64 = true

    is64

template deSerializeUleb128*(data: var HexString): untyped =

    var value, shift = 0'u32
    while value <= high(uint32):

        let byteVal = strutils.fromHex[byte]($(data[0..1]))
        data = data[2..^1] ## update data
        value = bitor(value, bitand(byteVal, 0x7F) shl shift)
        if bitand(byteVal, 0x80) == 0:

            break

        shift.inc(7)

    value

template deSerialize*[T](data: var HexString): untyped =

    when T is CountTable or T is CountTableRef or T is OrderedTable or
        T is OrderedTableRef or T is Table or T is TableRef:

        deSerializeHashTable[T](data)

    elif T is Option:

        deSerializeOption[T](data)

    elif T is int8 or T is uint8:

        var output = strutils.fromHex[T]($switchByteOrder(data[0..1]))
        if len(data) > 2:

            data = data[2..^1]

        else:

            data = fromString("")

        output

    elif T is int16 or T is uint16:

        var output = strutils.fromHex[T]($switchByteOrder(data[0..3]))
        if len(data) > 4:

            data = data[4..^1]

        else:

            data = fromString("")

        output

    elif T is int32 or T is uint32:

        var output = strutils.fromHex[T]($switchByteOrder(data[0..7]))
        if len(data) > 8:

            data = data[8..^1]

        else:

            data = fromString("")

        output

    elif T is int64 or T is uint64:

        var output = strutils.fromHex[T]($switchByteOrder(data[0..15]))
        if len(data) > 16:

            data = data[16..^1]

        else:

            data = fromString("")

        output

    elif T is int or T is uint:

        when Is64Bit:

            when T is int:

                int(deSerialize[int64](data))

            elif T is uint:

                uint(deSerialize[uint64](data))

        else:

            when T is int:

                int(deSerialize[int32](data))

            elif T is uint:

                uint(deSerialize[uint32](data))

    elif T is int128 or T is uint128:

        var output = largeints.fromHex[T]($switchByteOrder(data[0..31]))
        if len(data) > 32:

            data = data[32..^1]

        else:

            data = fromString("")

        output

    elif T is int256 or T is uint256:

        var output = largeints.fromHex[T]($switchByteOrder(data[0..63]))
        if len(data) > 64:

            data = data[64..^1]

        else:

            data = fromString("")

        output

    elif T is bool:

        deSerializeBool(data)

    elif T is HexString:

        deSerializeHexString(data)

    elif T is string:

        deSerializeStr(data)

    elif T is enum:

        deSerializeEnum[T](data)

    elif T is seq:

        deSerializeSeq[T](data)

    elif T is array:

        deSerializeArray[T](data)

    elif T is tuple:

        deSerializeTuple[T](data)

    else:

        {.error: $T & " is not supported".}

proc deSerializeHexString*(data: var HexString): HexString =

    let hexLen = deSerializeUleb128(data)
    result = data[0..hexLen - 1]

    if uint32(len(data)) > hexLen:

        data = data[hexLen..^1]

    else:

        data = fromString("")

proc deSerializeBool*(data: var HexString): bool =

    if $(data[0..1]) == "01":

        result = true

    elif $(data[0..1]) == "00":

        result = false

    else:

        raise newException(InvalidBcsStructure, "bool type structure is invalid")

    if len(data) > 2:

        data = data[2..^1]

proc deSerializeStr*(data: var HexString): string =

    let
        strLen = deSerializeUleb128(data)
        hexLen = (strLen * 2)

    result = parseHexStr($(data[0..hexLen - 1]))
    if uint32(len(data)) > hexLen:

        data = data[hexLen..^1]

    else:

        data = fromString("")

proc deSerializeEnum*[T: enum](data: var HexString): T =

    let enumPos = deSerializeUleb128(data)
    result = T(enumPos)
    if not (deSerializeStr(data) == $result):

        raise newException(InvalidBcsStructure, "enum type structure is invalid")

## deSerializeSeq, deSerializeArray, deSerializeTuple, deSerializeHashTable, deSerializeOption, are made to be
## templates to allow them call custom deSerialize[T](data : var HexString) : T
template deSerializeSeq*[T: seq](data: var HexString): untyped =

    var seqOutput: T
    let seqLen = deSerializeUleb128(data)
    for _ in 0..<seqLen:

        seqOutput.add deSerialize[genericParams(typedesc[T]).get(0)](data)

    seqOutput

template deSerializeArray*[T: array](data: var HexString): untyped =

    var arrayOutput: T
    for pos in 0..<len(T):

        arrayOutput[pos] = deSerialize[genericParams(typedesc[T]).get(1)](data)

    arrayOutput

template deSerializeTuple*[T: tuple](data: var HexString): untyped =

    var tupleOutput: T
    for val in fields(tupleOutput):

        val = deSerialize[typeof(val)](data)

    tupleOutput

template deSerializeHashTable*[T: CountTable | CountTableRef | OrderedTable |
        OrderedTableRef | Table | TableRef](data: var HexString): untyped =

    var tableOutput: T
    let tableLen = deSerializeUleb128(data)
    when T is CountTable or T is CountTableRef:

        for _ in 0..<tableLen:

            let key = deSerialize[genericParams(typedesc[T]).get(0)](data)
            let val = deSerialize[int](data)

            tableOutput[key] = val

    else:

        for _ in 0..<tableLen:

            let key = deSerialize[genericParams(typedesc[T]).get(0)](data)
            let val = deSerialize[genericParams(typedesc[T]).get(1)](data)

            tableOutput[key] = val

    tableOutput

template deSerializeOption*[T: Option](data: var HexString): untyped =

    var optionOutput: T
    if $data[0..1] == "00":

        if len(data) > 2:

            data = data[2..^1]

        else:

            data = fromString("")

        optionOutput = none[genericParams(typedesc[T]).get(0)]()

    elif $data[0..1] == "01":

        if len(data) > 2:

            data = data[2..^1]

        else:

            raise newException(InvalidBcsStructure, "option type is meant to contain data but, no data found")

        var optionValue: genericParams(typedesc[T]).get(0)
        when genericParams(typedesc[T]).get(0) is ref object:

            new(optionValue)

        optionValue = deSerialize[typeof(optionValue)](data)
        optionOutput = some(optionValue)

    else:

        raise newException(InvalidBcsStructure, "option type structure is invalid")

    optionOutput

