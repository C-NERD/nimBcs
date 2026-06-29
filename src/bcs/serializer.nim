#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
{.experimental: "codeReordering".}

from std / options import isNone, get, Option
from std / tables import CountTable, CountTableRef, OrderedTable,
        OrderedTableRef, Table, TableRef, len, pairs
from std / bitops import bitand, bitor
from std / enumutils import items

import constants, byteops

## Library extensibility:
## To extend the function of this library to cover custom serialization procs,
## create a `toBcsHookBytes` proc with params (x : T, y : var seq[byte])
## with:
##    T = custom datatype to be serialized
##
## example:
##    proc toBcsHookBytes(x : Address, y : var seq[byte]) =
##
##        let addrData = ($x)[2..^1]
##        for each in countup(0, len(addrData) - 1, 2):
##
##            y.add fromHex[uint8](addrData[each .. each + 1])
##
## notes ::
##
## 1. Enums are serialized and deserialized as BCS enum variant indexes: a
## single ULEB128-encoded 0-based variant position, matching how other BCS
## implementations (e.g. Rust/Aptos) encode enum variants. The index is the
## variant's position in declaration order (first = 0, second = 1, ...), not
## its `ord`, so enums with explicit/holed values (`enum A = 5, B = 9`) and
## string values (`enum Red = "red"`) are all encoded correctly.
##
## 2. A BCS bytes / `vector<u8>` value is just a `seq[uint8]` (a.k.a `seq[byte]`):
## it serializes to a ULEB128 length prefix followed by the raw bytes.

template serializeBytes*[T](data: T): untyped =
    ## serialize template, for unified way of calling serialization procs for all types

    var output: seq[byte]
    ## non native types are first so the conditions containing
    ## their native counterparts will be avoided
    when T is CountTable or T is CountTableRef or T is OrderedTable or
        T is OrderedTableRef or T is Table or T is TableRef:

        output.add serializeHashTableBytes(data)

    elif T is Option:

        output.add serializeOptionBytes(data)

    elif T is SomeInteger:

        var bytes: array[sizeof(T), byte]
        bytes = cast[array[sizeof(T), byte]](data)
        output.add switchByteOrder(@bytes)

    elif T is bool:

        output.add serializeBoolBytes(data)

    elif T is string:

        output.add serializeStrBytes(data)

    elif T is enum:

        output.add serializeEnumBytes(data)

    elif T is array or T is seq or T is tuple:

        output.add serializeArrayBytes(data)

    else:

        when compiles(toBcsHookBytes(data, output)):

            toBcsHookBytes(data, output)

        else:

            {.error: $T & " is not supported".}

    output

iterator serializeUleb128*(data: uint32): uint8 =
    ## iterator for serializing data length

    var data: uint32 = data
    while data >= 0x80:

        var byteVal = bitand(data, 0x7F)
        yield uint8(bitor(byteVal, 0x80))
        data = data shr 7

    yield uint8(bitand(data, 0x7F))

proc serializeBoolBytes*(data: bool): seq[byte] =
    ## serialize nim's bool type

    if data:

        return @[1'u8]

    return @[0'u8]

proc serializeStrBytes*(data: string): seq[byte] =
    ## serialize nim's string type

    let dataLen = len(data)
    if dataLen > int(MAX_SEQ_LENGHT):

        raise newException(InvalidSequenceLength,
                "string lenght is greater than " & $MAX_SEQ_LENGHT)

    for val in serializeUleb128(uint32(dataLen)):

        result.add serializeBytes(val)

    var strBytes: seq[byte]
    for character in data:

        var charByte = cast[byte](character)
        strBytes.add(charByte)

    result.add strBytes

proc bcsVariantIndex[T: enum](data: T): uint32 =
    ## BCS enum variant index: the 0-based position of `data` among T's
    ## declared variants, in declaration order. This is independent of `ord`,
    ## so enums with explicit/holed values (e.g. `enum A = 5, B = 9`) or string
    ## values (e.g. `enum Red = "red"`) all encode to the indexes other BCS
    ## implementations expect (0, 1, 2, ...).

    for variant in items(T):

        if variant == data: return

        inc result

proc serializeEnumBytes*[T: enum](data: T): seq[byte] =
    ## serialize nim's enum type as a BCS enum variant index (ULEB128)

    for val in serializeUleb128(bcsVariantIndex(data)):

        result.add serializeBytes(val)

## serializeArrayBytes, serializeHashTableBytes and serializeOptionBytes are made to be templates
## to allow for them to call custom serializeBytes[T](data : T) : seq[byte]
template serializeArrayBytes*(data: array | seq | tuple): untyped =
    ## serialize nim's array, seq or tuple types

    var arrayOutput: seq[byte]
    when data is tuple:

        for field in fields(data):

            arrayOutput.add serializeBytes(field)

    else:

        when data is seq:

            let dataLen = len(data)
            if dataLen > int(MAX_SEQ_LENGHT):

                raise newException(InvalidSequenceLength,
                        "seq lenght is greater than " & $MAX_SEQ_LENGHT)

            for val in serializeUleb128(uint32(dataLen)):

                arrayOutput.add serializeBytes(val)

        for item in data:

            arrayOutput.add serializeBytes(item)

    arrayOutput

template serializeHashTableBytes*(data: CountTable | CountTableRef | OrderedTable |
    OrderedTableRef | Table | TableRef): untyped =
    ## serialize nim's table types

    var tableOutput: seq[byte]
    for val in serializeUleb128(uint32(len(data))):

        tableOutput.add serializeBytes(val)

    for key, value in data:

        tableOutput.add serializeBytes((key, value))

    tableOutput

template serializeOptionBytes*[T](data: Option[T]): untyped =
    ## serialize nim's option type

    var optionOutput: seq[byte]
    if data.isNone:

        optionOutput.add 0'u8

    else:

        optionOutput.add 1'u8
        optionOutput.add serializeBytes(data.get())

    optionOutput
