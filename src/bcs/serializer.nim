#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
{.experimental: "codeReordering".}

from std / strutils import toHex
from std / options import isNone, get, Option
from std / tables import CountTable, CountTableRef, OrderedTable,
        OrderedTableRef, Table, TableRef, len, pairs
from std / typetraits import tupleLen
from std / bitops import bitand, bitor

import constants, largeints, hex

export toHex

## Library extensibility:
## To extend the function of this library to cover custom serialization procs,
## create a `toBcsHook` proc with params (x : T, y : var HexString)
## with:
##    T = custom datatype to be serialized
##
## example:
##    proc toBcsHook(x : Address, y : var HexString) =
##        y = fromString($x)
##
## known limitations ::
##
## 1. All nim enums are serialized and deserialized as string valued enums. So non string valued enums are not supported.
## Keep this in mind when interfacing with bcs libraries from other languages

template serialize*[T](data: T): untyped =
    ## serialize template, for unified way of calling serialization procs for all types

    var output: HexString
    ## non native types are first so the conditions containing
    ## their native counterparts will be avoided
    when T is CountTable or T is CountTableRef or T is OrderedTable or
        T is OrderedTableRef or T is Table or T is TableRef:

        output = serializeHashTable(data)

    elif T is Option:

        output = serializeOption(data)

    elif T is SomeInteger:

        output = switchByteOrder(fromString(strutils.toHex[T](data)))

    elif T is int128 or T is uint128 or T is int256 or T is uint256:

        output = switchByteOrder(fromString(largeints.toHex[T](data)))

    elif T is bool:

        output = serializeBool(data)

    elif T is HexString:

        output = serializeHexString(data)

    elif T is string:

        output = serializeStr(data)

    elif T is enum:

        output = serializeEnum(data)

    elif T is array or T is seq or T is tuple:

        output = serializeArray(data)

    else:

        when compiles(toBcsHook(data, output)):

            toBcsHook(data, output)

        else:

            {.error: $T & " is not supported".}

    output

iterator serializeUleb128*(data: uint32): uint8 =
    ## iterator for serializing data length

    var
        data: uint32 = data
        hasYield: bool = false
    while data > 0'u32:

        var byteVal: uint32 = bitand(data, 0x7F)
        data = data shr 7
        if data != 0'u32:

            byteVal = bitor(byteVal, 0x80)

        yield uint8(byteVal)
        if not hasYield:

            hasYield = true

    if not hasYield:

        yield 0'u8

proc serializeHexString*(data: HexString): HexString =
    ## serialize HexString, used to serialize bcs bytes type

    for val in serializeUleb128(uint32(byteLen(data))):

        result.add serialize(val)

    result.add data

proc serializeBool*(data: bool): HexString =
    ## serialize nim's bool type

    if data:

        return fromString("01")

    return fromString("00")

proc serializeStr*(data: string): HexString =
    ## serialize nim's string type

    let dataLen = len(data)
    if dataLen > int(MAX_SEQ_LENGHT):

        raise newException(InvalidSequenceLength,
                "string lenght is greater than " & $MAX_SEQ_LENGHT)

    for val in serializeUleb128(uint32(dataLen)):

        result.add serialize(val)

    result.add fromString(toHex(data))

proc serializeEnum*[T: enum](data: T): HexString =
    ## serialize nim's enum type

    for val in serializeUleb128(uint32(ord(data))):

        result.add serialize(val)

    result.add serialize($data) ## serialize as string enum

## serializeArray, serializeHashTable and serializeOption are made to be templates to allow for them
## to call custom serialize[T](data : T) : HexString
template serializeArray*(data: array | seq | tuple): untyped =
    ## serialize nim's array, seq or tuple types

    var arrayOutput: HexString
    when data is tuple:

        for field in fields(data):

            arrayOutput.add serialize(field)

    else:

        when data is seq:

            let dataLen = len(data)
            if dataLen > int(MAX_SEQ_LENGHT):

                raise newException(InvalidSequenceLength,
                        "seq lenght is greater than " & $MAX_SEQ_LENGHT)

            for val in serializeUleb128(uint32(dataLen)):

                arrayOutput.add serialize(val)

        for item in data:

            arrayOutput.add serialize(item)

    arrayOutput

template serializeHashTable*(data: CountTable | CountTableRef | OrderedTable |
        OrderedTableRef | Table | TableRef): untyped =
    ## serialize nim's table types

    var tableOutput: HexString
    for val in serializeUleb128(uint32(len(data))):

        tableOutput.add serialize(val)

    for key, value in data:

        tableOutput.add serialize((key, value))

    tableOutput

template serializeOption*[T](data: Option[T]): untyped =
    ## serialize nim's option type

    var optionOutput: HexString
    if data.isNone:

        optionOutput = fromString("00")

    else:

        optionOutput = serialize(data.get())
        optionOutput = fromString("01" & $optionOutput)

    optionOutput

