#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## known limitations ::
##
## 1. Because of my understanding on enums in nim, all nim enums are serialized and deserialized as string valued enums.
## So non string valued enums are not supported. Keep this in mind when interfacing with bcs libraries from
## other languages
{.experimental: "codeReordering".}

from std / strutils import toHex
from std / options import isNone, get, Option
from std / tables import CountTable, CountTableRef, OrderedTable, OrderedTableRef, Table, TableRef, len, pairs
from std / typetraits import tupleLen
from std / bitops import bitand, bitor, rotateRightBits

import constants, largeints, hex

export toHex

template serialize*[T](data : T) : untyped =
    
    var output : HexString
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

    elif T is string:

        output = serializeStr(data)

    elif T is enum:

        output = serializeEnum(data)

    elif T is array or T is seq or T is tuple:

        output = serializeArray(data)

    else:

        {.error : $T & " is not supported".}

    output

iterator serializeUleb128*(data : uint32) : uint8 =
    
    var data = data
    while data >= 0x80'u32:

        let byteVal = bitand(data, 0x7F)
        yield uint8(bitor(byteVal, 0x80))
        data = rotateRightBits(data, 7)

    yield uint8(bitand(data, 0x7F))

proc serializeBool*(data : bool) : HexString =

    if data:

        return fromString("01")

    else:

        return fromString("00")

proc serializeStr*(data : string) : HexString =
    
    let dataLen = len(data)
    if dataLen > int(MAX_SEQ_LENGHT):

        raise newException(InvalidSequenceLength, "string lenght is greater than " & $MAX_SEQ_LENGHT)
    
    for val in serializeUleb128(uint32(dataLen)):

        result.add serialize(val)

    result.add fromString(toHex(data))

proc serializeEnum*[T : enum](data : T) : HexString =
    
    for val in serializeUleb128(uint32(ord(data))):

        result.add serialize(val)

    result.add serialize($data) ## serialize as string enum

## serializeArray, serializeHashTable and serializeOption are made to be templates to allow for them 
## to call custom serialize[T](data : T) : HexString
template serializeArray*(data : array | seq | tuple) : untyped =
    ## serializes array, seq or tuple
    
    var arrayOutput : HexString
    when not(data is tuple):

        when data is seq:
        
            let dataLen = len(data)
            if dataLen > int(MAX_SEQ_LENGHT):

                raise newException(InvalidSequenceLength, "seq lenght is greater than " & $MAX_SEQ_LENGHT)

            for val in serializeUleb128(uint32(dataLen)):

                arrayOutput.add serialize(val)
        
        for item in data:
            
            arrayOutput.add serialize(item)

    else:
        
        for field in fields(data):

            arrayOutput.add serialize(field)

    arrayOutput

template serializeHashTable*(data : CountTable | CountTableRef | OrderedTable | OrderedTableRef | Table | TableRef) : untyped =
    
    var tableOutput : HexString
    for val in serializeUleb128(uint32(len(data))):

        tableOutput.add serialize(val)
    
    for key, value in pairs(data):
        
        tableOutput.add serialize((key, value))

    tableOutput

template serializeOption*[T](data : Option[T]) : untyped =
    
    var optionOutput : HexString
    if data.isNone:

        optionOutput = fromString("00")

    else:
        
        optionOutput = serialize(data.get())
        optionOutput = fromString("01" & $optionOutput)

    optionOutput

