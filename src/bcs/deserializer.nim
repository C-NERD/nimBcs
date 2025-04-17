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

import constants, hex, byteops

export fromHex, genericParams, get

## Library extensibility:
## To extend the function of this library to cover custom deSerialization procs,
## create a `fromBcsHook` proc with params (x : var HexString, y : var T)
## with:
##    T = custom datatype to be deSerialized to
##
## example:
##    proc fromBcsHook(x : var HexString, y : var Address) =
##        if x == fromString("00"):
##            y = initAddress("0x00")
##
## Note :: param `x` is required to be of type var HexString as it is expected that
## once the hex representing the data to be deserialized by the custom hook proc are processed,
## the hex representing the data should be removed from the `x` variable leaving only
## undeserialized data
## To extend the function of this library to cover custom deSerializationBytes procs,
## create a `fromBcsHookBytes` proc with params (x : var seq[byte], y : var T)
## with:
##    T = custom datatype to be deSerialized to
##
## example:
##    proc fromBcsHookBytes(x : var seq[byte], y : var Address) =
##        if x[0] == 0'u8:
##            y = initAddress("0x00")
##
## Note :: param `x` is required to be of type var seq[byte] as it is expected that
## once the bytes representing the data to be deserialized by the custom hook proc are processed,
## the bytes representing the data should be removed from the `x` variable leaving only
## undeserialized data

const Is64Bit*: bool =

    block:

        var is64: bool = false
        if high(int) == high(int64):

            is64 = true

        is64

    ## for checking if compilation enviroment is 64bit

template deSerializeUleb128*(data: var HexString): untyped =
    ## deserialize bcs data length

    var value: uint64
    for shift in countup(0, 32, 7):

        let byteVal: byte = strutils.fromHex[byte]($data[0..1])
        data = data[2..^1] ## update data
        let digit = bitand(byteVal, 0x7F)
        value = bitor(value, uint64(digit) shl shift)
        if digit == byteVal: ## checks if at the last byte of sequence

            if shift > 0 and digit == 0:

                raise newException(ValueError, "Not canonical uleb128 encoding")

            break

    uint32(value)

template deSerializeUleb128Bytes*(data: var seq[byte]): untyped =
    ## deserialize bcs data length

    var value: uint64
    for shift in countup(0, 32, 7):

        let byteVal: byte = data[0]
        data = data[1..^1] ## update data
        let digit = bitand(byteVal, 0x7F)
        value = bitor(value, uint64(digit) shl shift)
        if digit == byteVal: ## checks if at the last byte of sequence

            if shift > 0 and digit == 0:

                raise newException(ValueError, "Not canonical uleb128 encoding")

            break

    uint32(value)

template deSerialize*[T](data: var HexString): untyped =
    ## deserialize template, for unified way of calling deserialization procs for all types

    when T is CountTable or T is CountTableRef or T is OrderedTable or
        T is OrderedTableRef or T is Table or T is TableRef:

        deSerializeHashTable[T](data)

    elif T is Option:

        deSerializeOption[T](data)

    elif T is int8 or T is uint8:

        var output: T = strutils.fromHex[T]($switchByteOrder(data[0..1]))
        if len(data) > 2:

            data = data[2..^1]

        else:

            data = fromString("")

        output

    elif T is int16 or T is uint16:

        var output: T = strutils.fromHex[T]($switchByteOrder(data[0..3]))
        if len(data) > 4:

            data = data[4..^1]

        else:

            data = fromString("")

        output

    elif T is int32 or T is uint32:

        var output: T = strutils.fromHex[T]($switchByteOrder(data[0..7]))
        if len(data) > 8:

            data = data[8..^1]

        else:

            data = fromString("")

        output

    elif T is int64 or T is uint64:

        var output: T = strutils.fromHex[T]($switchByteOrder(data[0..15]))
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

        var output: T
        when compiles(fromBcsHook(data, output)):

            fromBcsHook(data, output)

        else:

            {.error: $T & " is not supported".}

        output

template deSerializeBytes*[T](data: var seq[byte]): untyped =
    ## deserialize template, for unified way of calling deserialization procs for all types

    when T is CountTable or T is CountTableRef or T is OrderedTable or
        T is OrderedTableRef or T is Table or T is TableRef:

        deSerializeHashTableBytes[T](data)

    elif T is Option:

        deSerializeOptionBytes[T](data)

    elif T is int8 or T is uint8:

        let byteVal: byte = data[0]
        var output: T
        when T is int8:

            output = cast[T](byteVal)

        else:

            output = byteVal

        del data, 0
        output

    elif T is int16 or T is uint16:

        var bytes: seq[byte] = @[data[0], data[1]]
        bytes = switchByteOrder(bytes)
        let byteArray: array[2, byte] = [bytes[0], bytes[1]]
        var output: T = cast[T](byteArray)
        data = data[2..^1]

        output

    elif T is int32 or T is uint32:

        var bytes: seq[byte] = @[data[0], data[1], data[2], data[3]]
        bytes = switchByteOrder(bytes)
        let byteArray: array[4, byte] = [bytes[0], bytes[1], bytes[2], bytes[3]]
        var output: T = cast[T](byteArray)
        data = data[4..^1]

        output

    elif T is int64 or T is uint64:

        var bytes: seq[byte] = @[data[0], data[1], data[2], data[3], data[4],
                data[5], data[6], data[7]]
        bytes = switchByteOrder(bytes)
        let byteArray: array[8, byte] = [bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7]]
        var output: T = cast[T](byteArray)
        data = data[8..^1]

        output

    elif T is int or T is uint:

        when Is64Bit:

            when T is int:

                int(deSerializeBytes[int64](data))

            elif T is uint:

                uint(deSerializeBytes[uint64](data))

        else:

            when T is int:

                int(deSerializeBytes[int32](data))

            elif T is uint:

                uint(deSerializeBytes[uint32](data))

    elif T is bool:

        deSerializeBoolBytes(data)

    elif T is HexString:

        deSerializeHexStringBytes(data)

    elif T is string:

        deSerializeStrBytes(data)

    elif T is enum:

        deSerializeEnumBytes[T](data)

    elif T is seq:

        deSerializeSeqBytes[T](data)

    elif T is array:

        deSerializeArrayBytes[T](data)

    elif T is tuple:

        deSerializeTupleBytes[T](data)

    else:

        var output: T
        when compiles(fromBcsHookBytes(data, output)):

            fromBcsHookBytes(data, output)

        else:

            {.error: $T & " is not supported".}

        output

proc deSerializeHexString*(data: var HexString): HexString =
    ## deserialize HexString, used to deserialize serialized bcs bytes type

    let hexLen: uint32 = deSerializeUleb128(data)
    result = data[0..hexLen - 1]

    data = data[hexLen..^1]

proc deSerializeHexStringBytes*(data: var seq[byte]): HexString =
    ## deserialize HexString, used to deserialize serialized bcs bytes type

    let hexLen: uint32 = deSerializeUleb128Bytes(data)
    result = hex.fromBytes(data[0..hexLen - 1])

    data = data[hexLen..^1]

proc deSerializeBool*(data: var HexString): bool =
    ## deserialize into nim's bool type

    if $(data[0..1]) == "01":

        result = true

    elif $(data[0..1]) == "00":

        result = false

    else:

        raise newException(InvalidBcsStructure, "bool type structure is invalid")

    data = data[2..^1]

proc deSerializeBoolBytes*(data: var seq[byte]): bool =
    ## deserialize into nim's bool type

    if data[0] == 1:

        result = true

    elif data[0] == 0:

        result = false

    else:

        raise newException(InvalidBcsStructure, "bool type structure is invalid")

    data = data[1..^1]

proc deSerializeStr*(data: var HexString): string =
    ## deserialize into nim's string type

    let
        strLen: uint32 = deSerializeUleb128(data)
        hexLen: uint32 = (strLen * 2)

    result = parseHexStr($(data[0..hexLen - 1]))
    data = data[hexLen..^1]

proc deSerializeStrBytes*(data: var seq[byte]): string =
    ## deserialize into nim's string type

    let strLen: uint32 = deSerializeUleb128Bytes(data)
    for pos in 0..<strLen:

        var x: char
        x = cast[char](data[pos])
        result.add x

    data = data[strLen..^1]

proc deSerializeEnum*[T: enum](data: var HexString): T =
    ## deserialize into nim's enum type
    let enumPos: uint32 = deSerializeUleb128(data)
    result = T(enumPos)
    if not (deSerializeStr(data) == $result):

        raise newException(InvalidBcsStructure, "enum type structure is invalid")

proc deSerializeEnumBytes*[T: enum](data: var seq[byte]): T =
    ## deserialize into nim's enum type

    let enumPos: uint32 = deSerializeUleb128Bytes(data)
    result = T(enumPos)
    let enumStrBytes = deSerializeStrBytes(data)
    var enumStr: string
    for pos in 0..<len(enumStrBytes):

        var x: char
        x = cast[char](enumStrBytes[pos])
        enumStr.add x

    if not (enumStr == $result):

        raise newException(InvalidBcsStructure, "enum type structure is invalid")

## deSerializeSeq, deSerializeArray, deSerializeTuple, deSerializeHashTable, deSerializeOption, are made to be
## templates to allow them call custom deSerialize[T](data : var HexString) : T
template deSerializeSeq*[T: seq](data: var HexString): untyped =
    ## deserialize into nim's seq type

    var seqOutput: T
    let seqLen: uint32 = deSerializeUleb128(data)
    for _ in 0..<seqLen:

        seqOutput.add deSerialize[genericParams(typedesc[T]).get(0)](data)

    seqOutput

template deSerializeSeqBytes*[T: seq](data: var seq[byte]): untyped =
    ## deserialize into nim's seq type

    var seqOutput: T
    let seqLen: uint32 = deSerializeUleb128Bytes(data)
    for _ in 0..<seqLen:

        seqOutput.add deSerializeBytes[genericParams(typedesc[T]).get(0)](data)

    seqOutput

template deSerializeArray*[T: array](data: var HexString): untyped =
    ## deserialize into nim's array type

    var arrayOutput: T
    for pos in 0..<len(T):

        arrayOutput[pos] = deSerialize[genericParams(typedesc[T]).get(1)](data)

    arrayOutput

template deSerializeArrayBytes*[T: array](data: var seq[byte]): untyped =
    ## deserialize into nim's array type

    var arrayOutput: T
    for pos in 0..<len(T):

        arrayOutput[pos] = deSerializeBytes[genericParams(typedesc[T]).get(1)](data)

    arrayOutput

template deSerializeTuple*[T: tuple](data: var HexString): untyped =
    ## deserialize into nim's tuple type

    var tupleOutput: T
    for val in fields(tupleOutput):

        val = deSerialize[typeof(val)](data)

    tupleOutput

template deSerializeTupleBytes*[T: tuple](data: var seq[byte]): untyped =
    ## deserialize into nim's tuple type

    var tupleOutput: T
    for val in fields(tupleOutput):

        val = deSerializeBytes[typeof(val)](data)

    tupleOutput

template deSerializeHashTable*[T: CountTable | CountTableRef | OrderedTable |
        OrderedTableRef | Table | TableRef](data: var HexString): untyped =
    ## deserialize into nim's table types

    var tableOutput: T
    let tableLen: uint32 = deSerializeUleb128(data)
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

template deSerializeHashTableBytes*[T: CountTable | CountTableRef |
        OrderedTable | OrderedTableRef | Table | TableRef](data: var seq[
                byte]): untyped =
    ## deserialize into nim's table types

    var tableOutput: T
    let tableLen: uint32 = deSerializeUleb128Bytes(data)
    when T is CountTable or T is CountTableRef:

        for _ in 0..<tableLen:

            let key = deSerializeBytes[genericParams(typedesc[T]).get(0)](data)
            let val = deSerializeBytes[int](data)

            tableOutput[key] = val

    else:

        for _ in 0..<tableLen:

            let key = deSerializeBytes[genericParams(typedesc[T]).get(0)](data)
            let val = deSerializeBytes[genericParams(typedesc[T]).get(1)](data)

            tableOutput[key] = val

    tableOutput

template deSerializeOption*[T: Option](data: var HexString): untyped =
    ## deserialize into nim's option type

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

template deSerializeOptionBytes*[T: Option](data: var seq[byte]): untyped =
    ## deserialize into nim's option type

    var optionOutput: T
    if data[0] == 0'u8:

        data = data[1..^1]
        optionOutput = none[genericParams(typedesc[T]).get(0)]()

    elif data[0] == 1'u8:

        if len(data) > 1:

            data = data[1..^1]

        else:

            raise newException(InvalidBcsStructure, "option type is meant to contain data but, no data found")

        var optionValue: genericParams(typedesc[T]).get(0)
        when genericParams(typedesc[T]).get(0) is ref object:

            new(optionValue)

        optionValue = deSerializeBytes[typeof(optionValue)](data)
        optionOutput = some(optionValue)

    else:

        raise newException(InvalidBcsStructure, "option type structure is invalid")

    optionOutput

