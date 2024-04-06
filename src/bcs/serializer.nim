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

        output = switchByteOrder(strutils.toHex[T](data))

    elif T is int128 or T is uint128 or T is int256 or T is uint256:

        output = switchByteOrder(largeints.toHex[T](data))

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

    result.add toHex(data)

proc serializeEnum*[T : enum](data : T) : HexString =
    
    for val in serializeUleb128(uint32(ord(data))):

        result.add serialize(val)

    result.add serialize($data) ## serialize as string enum

proc serializeArray*(data : array | seq | tuple) : HexString =
    ## serializes array, seq or tuple
        
    when not(data is tuple):

        when data is seq:
        
            let dataLen = len(data)
            if dataLen > int(MAX_SEQ_LENGHT):

                raise newException(InvalidSequenceLength, "seq lenght is greater than " & $MAX_SEQ_LENGHT)

            for val in serializeUleb128(uint32(dataLen)):

                result.add serialize(val)
        
        for item in data:
            
            result.add serialize(item)

    else:
        
        for field in fields(data):

            result.add serialize(field)

proc serializeHashTable*(data : CountTable | CountTableRef | OrderedTable | OrderedTableRef | Table | TableRef) : HexString =
    
    for val in serializeUleb128(uint32(len(data))):

        result.add serialize(val)
    
    for key, value in pairs(data):
        
        result.add serialize((key, value))

proc serializeOption*[T](data : Option[T]) : HexString =

    if data.isNone:

        return fromString("00")

    else:
        
        result = serialize(data.get())
        result = fromString("01" & $result)

