#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
{.experimental: "codeReordering".}

from std / strutils import parseHexStr, fromHex
from std / options import Option, none, get, some
from std / tables import CountTable, CountTableRef, OrderedTable, OrderedTableRef, Table, TableRef, `[]=`
from std / typetraits import genericParams, tupleLen, get
from std / bitops import bitand, bitor, rotateLeftBits

import constants, int128, utils

export fromHex, genericParams, get

template deSerializeUleb128*(data : var string) : untyped =

    var value, shift = 0'u32
    while value <= high(uint32):

        let byteVal = strutils.fromHex[byte](data[0..1])
        data = data[2..^1] ## update data
        value = bitor(value, rotateLeftBits(bitand(byteVal, 0x7F), shift))
        if bitand(byteVal, 0x80) == 0:

            break

        shift.inc(7)

    value

template deSerialize*[T](data : var string, output : var T) : untyped =

    when T is CountTable or T is CountTableRef or T is OrderedTable or 
        T is OrderedTableRef or T is Table or T is TableRef:

        output = deSerializeHashTable[T](data)

    elif T is Option:

        output = deSerializeOption[T](data)

    elif T is int8 or T is uint8:

        output = strutils.fromHex[T](switchByteOrder(data[0..1]))
        if len(data) > 2:

            data = data[2..^1]

        else:

            data = ""

    elif T is int16 or T is uint16:

        output = strutils.fromHex[T](switchByteOrder(data[0..3]))
        if len(data) > 4:

            data = data[4..^1]

        else:

            data = ""

    elif T is int32 or T is uint32:

        output = strutils.fromHex[T](switchByteOrder(data[0..7]))
        if len(data) > 8:
            
            data = data[8..^1]

        else:

            data = ""

    elif T is int64 or T is uint64:

        output = strutils.fromHex[T](switchByteOrder(data[0..15]))
        if len(data) > 16:

            data = data[16..^1]

        else:

            data = ""

    elif T is int or T is uint:

        when Is64Bit:
            
            when T is int:

                var newOutput : int64

            elif T is uint:

                var newOutput : uint64

        else:

            when T is int:

                var newOutput : int32

            elif T is uint:

                var newOutput : uint32

        deSerialize(data, newOutput)
        output = T(newOutput)

    elif T is int128 or T is uint128:

        output = int128.fromHex[T](switchByteOrder(data[0..31]))
        if len(data) > 32:

            data = data[32..^1]

        else:

            data = ""

    elif T is bool:

        output = deSerializeBool(data)

    elif T is string:

        output = deSerializeStr(data)

    elif T is enum:

        output = deSerializeEnum[T](data)

    elif T is seq: 

        output = deSerializeSeq[T](data)

    elif T is array:

        output = deSerializeArray[T](data)

    elif T is tuple:

        output = deSerializeTuple[T](data)

    elif T is object or T is ref object:

        output = deSerializeObj[T](data)

proc deSerializeBool*(data : var string) : bool =

    if data[0..1] == "01":
        
        result = true

    elif data[0..1] == "00":

        result = false

    else:

        raise newException(InvalidBcsStructure, "bool type structure is invalid")
    
    if len(data) > 2:
         
        data = data[2..^1]

proc deSerializeStr*(data : var string) : string = 
    
    let 
        strLen = deSerializeUleb128(data)
        hexLen = (strLen * 2)
    
    result = parseHexStr(data[0..hexLen - 1])
    if uint32(len(data)) > hexLen:

        data = data[hexLen..^1]

    else:

        data = ""

proc deSerializeEnum*[T : enum](data : var string) : T =

    let enumPos = deSerializeUleb128(data)
    result = T(enumPos)
    if not (deSerializeStr(data) == $result):
        
        raise newException(InvalidBcsStructure, "enum type structure is invalid")

proc deSerializeSeq*[T : seq](data : var string) : T =
    
    let seqLen = deSerializeUleb128(data)
    var item : genericParams(typedesc[T]).get(0)
    for _ in 0..<seqLen:

        deSerialize(data, item)
        result.add item

proc deSerializeArray*[T : array](data : var string) : T =
    
    var item : genericParams(typedesc[T]).get(1)
    for pos in 0..<len(T):

        deSerialize(data, item)
        result[pos] = item

proc deSerializeTuple*[T : tuple](data : var string) : T =
    
    for val in fields(result):

        var item : typeof(val)
        deSerialize(data, item)

        val = item

proc deSerializeObj*[T : object | ref object](data : var string) : T =
    
    when T is ref object:

        var refResultSub : T 
        new(refResultSub)
        var resultSub = refResultSub[]

    elif T is object:

        var resultSub : T

    for field in fields(resultSub):

        deSerialize(data, field)
    
    when T is ref object:
        
        refResultSub[] = resultSub
        return refResultSub

    else:
        
        result = resultSub
        for key, value1, value2 in fieldPairs(result, resultSub):
            ## NOTE :: This implementation is because of a bug that occurs when
            ## resultSub is copied to result. This bug converts the value of any int128
            ## and uint128 type to 0. This bug is only found for object types and not
            ## ref object types.
            ## So until this is fixed avoid using int128 and uint128 types in nested seq,
            ## array or object inside of a larger object to be deserialized

            when value1 is int128.int128 or value1 is uint128:

                value1 = value2

proc deSerializeHashTable*[T : CountTable | CountTableRef | OrderedTable | OrderedTableRef | Table | TableRef](data : var string) : T =
    
    let tableLen = deSerializeUleb128(data)
    when T is CountTable or T is CountTableRef:
        
        var item : tuple[key : genericParams(typedesc[T]).get(0), val : int]
        for _ in 0..<tableLen:

            deSerialize(data, item.key)
            deSerialize(data, item.val)

            result[item[0]] = item[1]

    else:
        
        var item : tuple[key : genericParams(typedesc[T]).get(0), val : genericParams(typedesc[T]).get(1)]
        for _ in 0..<tableLen:

            deSerialize(data, item.key)
            deSerialize(data, item.val)

            result[item[0]] = item[1]

proc deSerializeOption*[T : Option](data : var string) : T =

    if data[0..1] == "00":
        
        if len(data) > 2:

            data = data[2..^1]

        else:

            data = ""

        return none[genericParams(typedesc[T]).get(0)]()

    elif data[0..1] == "01":

        if len(data) > 2:

            data = data[2..^1]

        else:

            raise newException(InvalidBcsStructure, "option type is meant to contain data but, no data found")
        
        var optionValue : genericParams(typedesc[T]).get(0)
        when genericParams(typedesc[T]).get(0) is ref object:

            new(optionValue)

        result = some(optionValue)
        deSerialize(data, result.get())

    else:

        raise newException(InvalidBcsStructure, "option type structure is invalid")


