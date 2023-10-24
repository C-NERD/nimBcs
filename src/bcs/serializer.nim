#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## known limitations ::
##
## 1. Infinite recursion occurs for recursive objects with a ref field of themselves.
## This is because the bcs format does not account for nil types in ref objects, at
## least from the sources I have read. So, if you want to use a recursive type. try using
## it in an Option type or don't use it at all. Until there are changes to the bcs structure
##
## 2. Since this library works by means of string operations, and nim strings are 
## implemented as char bytes. This library cannot differenciate between normal strings and 
## hex strings but you can implement one specific for your needs with this library
##
## 3. Because of my understanding on enums in nim, all nim enums are serialized and deserialized as string valued enums.
## So non string valued enums are not supported. Keep this in mind when interfacing with bcs libraries from
## other languages
{.experimental: "codeReordering".}

from std / strutils import toHex
from std / options import isNone, get, Option
from std / tables import CountTable, CountTableRef, OrderedTable, OrderedTableRef, Table, TableRef, len, pairs
from std / typetraits import tupleLen
from std / bitops import bitand, bitor, rotateRightBits

import constants, int128, utils

export toHex

template serialize*[T](data : T, output : var string) =
    
    ## non native types are first so the conditions containing
    ## their native counterparts will be avoided
    when T is CountTable or T is CountTableRef or T is OrderedTable or 
        T is OrderedTableRef or T is Table or T is TableRef:

        output = serializeHashTable(data)

    elif T is Option:

        output = serializeOption(data)

    elif T is SomeInteger:

        output = switchByteOrder(strutils.toHex[T](data))

    elif T is int128 or T is uint128:

        output = switchByteOrder(int128.toHex[T](data))

    elif T is bool:

        output = serializeBool(data)

    elif T is string:

        output = serializeStr(data)

    elif T is enum:

        output = serializeEnum(data)

    elif T is array or T is seq or T is tuple:

        output = serializeArray(data)

    elif T is object or T is ref object:

        output = serializeObj(data)

iterator serializeUleb128*(data : uint32) : uint8 =
    
    var data = data
    while data >= 0x80'u32:

        let byteVal = bitand(data, 0x7F)
        yield uint8(bitor(byteVal, 0x80))
        data = rotateRightBits(data, 7)

    yield uint8(bitand(data, 0x7F))

proc serializeBool*(data : bool) : string =

    if data:

        return "01"

    else:

        return "00"

proc serializeStr*(data : string) : string =
    
    let dataLen = len(data)
    if dataLen > int(MAX_SEQ_LENGHT):

        raise newException(InvalidSequenceLength, "string lenght is greater than " & $MAX_SEQ_LENGHT)
    
    var serData : string
    for val in serializeUleb128(uint32(dataLen)):

        serialize(val, serData)
        result.add serData

    result.add toHex(data)

proc serializeEnum*[T : enum](data : T) : string =
    
    var serData : string
    for val in serializeUleb128(uint32(ord(data))):

        serialize(val, serData)
        result.add serData

    var strOutput : string
    serialize($data, strOutput)
    result.add strOutput

proc serializeArray*(data : array | seq | tuple) : string =
    ## serializes array, seq or tuple
        
    when not(data is tuple):

        when data is seq:
        
            let dataLen = len(data)
            if dataLen > int(MAX_SEQ_LENGHT):

                raise newException(InvalidSequenceLength, "seq lenght is greater than " & $MAX_SEQ_LENGHT)
            
            var serData : string
            for val in serializeUleb128(uint32(dataLen)):

                serialize(val, serData)
                result.add serData
        
        var serData2 : string
        for item in data:
            
            serialize(item, serData2)
            result.add serData2

    else:
        
        var serData : string
        for field in fields(data):

            serialize(field, serData)
            result.add serData

proc serializeObj*(data : object | ref object) : string =

    when data is ref object:
        
        var refData = data
        if refData.isNil():
            
            new(refData)

        let data = refData[]
    
    var serData : string
    for field in fields(data):

        serialize(field, serData)
        result.add serData

proc serializeHashTable*(data : CountTable | CountTableRef | OrderedTable | OrderedTableRef | Table | TableRef) : string =
    
    var serData : string
    for val in serializeUleb128(uint32(len(data))):

        serialize(val, serData)
        result.add serData
    
    var tupleOutput : string
    for key, value in pairs(data):
        
        serialize((key, value), tupleOutput)
        result.add tupleOutput

proc serializeOption*[T](data : Option[T]) : string =

    if data.isNone:

        return "00"

    else:
        
        var serData : string
        serialize(data.get(), serData)

        return "01" & serData

