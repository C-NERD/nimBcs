#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
## known limitations
## 1. infinite recursion occurs for recursive objects with a ref field of themselves.
## This is because the bcs format does not account for nil types in ref objects, at
## least from the sources I have read. So, if you want to use a recursive type. try using
## it in an Option type or don't use it at all. Until there are changes to the bcs structure
## 2. since this library works by means of string operations, and nim strings are 
## implemented as char bytes. This library cannot differenciate between normal strings and 
## hex strings but you can implement one specific for your needs with this library
{.experimental: "codeReordering".}

from std / strutils import toHex
from std / options import isNone, get, Option
from std / tables import CountTable, CountTableRef, OrderedTable, OrderedTableRef, Table, TableRef, len, pairs
#from std / strformat import fmt
from std / typetraits import tupleLen

import constants, int128

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

        output = strutils.toHex(data)

    elif T is int128 or T is uint128:

        output = int128.toHex(data)

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

proc serializeBool*(data : bool) : string =

    if data:

        return "01"

    else:

        return "00"

proc serializeStr*(data : string) : string =
    
    let dataLen = len(data)
    if dataLen > int(MAX_SEQ_LENGHT):

        raise newException(InvalidSequenceLength, "string lenght is greater than " & $MAX_SEQ_LENGHT)

    serialize(uint64(dataLen), result)
    result.add toHex(data)

proc serializeEnum*[T : enum](data : T) : string =

    serialize(uint32(ord(data)), result)
    var strOutput : string
    serialize($data, strOutput)
    result.add strOutput

proc serializeArray*(data : array | seq | tuple) : string =
    ## serializes array, seq and tuple
    
    when not(data is tuple):

        let dataLen = len(data)

    else:

        let dataLen = tupleLen(data) ## I don't know why i am defining this
        ## probably bloatware to be removed in the future
    
    when data is seq:
        
        if len(data) > int(MAX_SEQ_LENGHT):

            raise newException(InvalidSequenceLength, "seq lenght is greater than " & $MAX_SEQ_LENGHT)

        serialize(uint64(dataLen), result)
    
    when not(data is tuple):

        for item in data:
            
            var serData : string
            serialize(item, serData)

            result.add serData

    else:

        for field in fields(data):

            var serData : string
            serialize(field, serData)

            result.add serData

proc serializeObj*(data : object | ref object) : string =

    when data is ref object:
        
        var refData = data
        if refData.isNil():
            
            new(refData)

        let data = refData[]

    for field in fields(data):

        var serData : string
        serialize(field, serData)

        result.add serData

proc serializeHashTable*(data : CountTable | CountTableRef | OrderedTable | OrderedTableRef | Table | TableRef) : string =

    serialize(uint64(len(data)), result)
    for key, value in pairs(data):
        
        var tupleOutput : string
        serialize((key, value), tupleOutput)

        result.add tupleOutput

proc serializeOption*[T](data : Option[T]) : string =

    if data.isNone:

        return "00"

    else:
        
        var serData : string
        serialize(data.get(), serData)

        return "01" & serData

