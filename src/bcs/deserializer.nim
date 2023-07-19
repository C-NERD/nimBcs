#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
{.experimental: "codeReordering".}

from std / strutils import parseHexStr, fromHex
from std / options import Option, none, get, some
from std / tables import CountTable, CountTableRef, OrderedTable, OrderedTableRef, Table, TableRef, `[]=`
#from std / strformat import fmt
from std / typetraits import genericParams, tupleLen, get

import constants, int128

export fromHex, genericParams, get

template tokenize[T](data : var string, output : var string) : untyped =

    when T is CountTable or T is CountTableRef or T is OrderedTable or 
        T is OrderedTableRef or T is Table or T is TableRef:
            
        tokenizeTable[T](data, output)

    elif T is Option:
        
        tokenizeOption[T](data, output)

    elif T is int8 or T is uint8:

        output = data[0..1]
        data = data[2..^1]

    elif T is int16 or T is uint16:

        output = data[0..3]
        data = data[4..^1]

    elif T is int32 or T is uint32:

        output = data[0..7]
        data = data[8..^1]

    elif T is int64 or T is uint64 or T is int or T is uint:

        output = data[0..15]
        data = data[16..^1]

    elif T is int128 or T is uint128:

        output = data[0..31]
        data = data[32..^1]

    elif T is bool:

        output = data[0..1]
        data = data[2..^1]

    elif T is string:

        let 
            strLenHex = data[0..15]
            strHexLen = 15 + (strutils.fromHex[uint64](strLenHex) * 2)

        output = strLenHex & data[16..strHexLen]
        data = data[(strHexLen + 1)..^1]

    elif T is enum:

        output = data[0..7]
        data = data[8..^1]

        let 
            strLenHex = data[0..15]
            strHexLen = 15 + (strutils.fromHex[uint64](strLenHex) * 2)

        output.add (strLenHex & data[16..strHexLen])
        data = data[(strHexLen + 1)..^1]

    elif T is seq:

        tokenizeSeq[T](data, output)

    elif T is array:

        tokenizeArray[T](data, output)

    elif T is tuple:

        tokenizeTuple[T](data, output)

    elif T is object or T is ref object:
        
        tokenizeObject[T](data, output)

template deSerialize*[T](data : string, output : var T) : untyped =

    when T is CountTable or T is CountTableRef or T is OrderedTable or 
        T is OrderedTableRef or T is Table or T is TableRef:

        output = deSerializeHashTable[T](data)

    elif T is Option:

        output = deSerializeOption[T](data)

    elif T is SomeInteger:

        output = strutils.fromHex[T](data)

    elif T is int128 or T is uint128:

        output = int128.fromHex[T](data)

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

proc tokenizeSeq*[T : seq](data, output : var string) =
    
    output = data[0..15]
    data = data[16..^1]
    let seqLen = int(strutils.fromHex[uint64](output))
    for _ in 1..seqLen:
            
        var newOutput : string
        tokenize[genericParams(typedesc[T]).get(0)](data, newOutput)
        
        output.add newOutput

proc tokenizeArray*[T : array](data, output : var string) =

    let arrayLen = len(T)
    for _ in 1..arrayLen:

        var newOutput : string
        tokenize[genericParams(typedesc[T]).get(1)](data, newOutput)

        output.add newOutput

proc tokenizeTuple*[T : tuple](data, output : var string) =
    
    #let tupleItems = genericParams(typedesc[T])
    var testTuple : T
    for val in fields(testTuple):
         
        var newOutput : string
        tokenize[typeof(val)](data, newOutput)

        output.add newOutput

proc tokenizeObject*[T : object | ref object](data, output : var string) =

    when T is object:

        var iterObj : T ## create variable that can be iterated upon

    elif T is ref object:

        var refIterObj : T
        new refIterObj
        var iterObj = refIterObj[]

    for field in fields(iterObj):

        var newOutput : string

        tokenize[typeof(field)](data, newOutput)
        output.add newOutput

proc tokenizeTable*[T : CountTable | CountTableRef | OrderedTable | OrderedTableRef | Table | TableRef](data, output : var string) =

    output = data[0..15]
    data = data[16..^1]
    let mapLen = strutils.fromHex[uint64](output)
    when T is CountTable or T is CountTableRef:
          
        for _ in 0..<int(mapLen):
         
            var newOutput : string
            tokenize[genericParams(typedesc[T]).get(0)](data, newOutput)
            output.add newOutput

            newOutput = ""
            tokenize[int](data, newOutput)
            output.add newOutput

    else:

        for _ in 0..<int(mapLen):

            var newOutput : string
            tokenize[genericParams(typedesc[T]).get(0)](data, newOutput)
            output.add newOutput

            newOutput = ""
            tokenize[genericParams(typedesc[T]).get(1)](data, newOutput)
            output.add newOutput

proc tokenizeOption*[T : Option](data, output : var string) =

    output = data[0..1]
    data = data[2..^1]
    if output == "00":

        discard ## do noting here. Already did something above

    elif output == "01":

        var newOutput : string

        tokenize[genericParams(typedesc[T]).get(0)](data, newOutput)
        output.add newOutput

    else:

        raise newException(InvalidBcsStructure, "option type structure is invalid")

proc deSerializeBool*(data : string) : bool =

    if data == "01":

        return true

    elif data == "00":

        return false

proc deSerializeStr*(data : string) : string = 
    
    let seqLen = strutils.fromHex[uint64](data[0..15])
    if seqLen > uint64(MAX_SEQ_LENGHT):

        raise newException(InvalidSequenceLength, "string lenght is greater than " & $MAX_SEQ_LENGHT)

    return parseHexStr(data[16..^1])

proc deSerializeEnum*[T : enum](data : string) : T =

    let 
        enumPos = data[0..7]
        enumData = data[8..^1]
    
    result = T(strutils.fromHex[uint32](enumPos))
    if deSerializeStr(enumData) != $result:

        raise newException(InvalidBcsStructure, "enum type structure is invalid")

proc deSerializeSeq*[T : seq](data : string) : T =
    
    var 
        seqLen = strutils.fromHex[uint64](data[0..15])
        data = data[16..^1]

    if seqLen > uint64(MAX_SEQ_LENGHT):

        raise newException(InvalidSequenceLength, "seq lenght is greater than " & $MAX_SEQ_LENGHT)

    for _ in 0..<seqLen:

        var itemBcs : string
        tokenize[genericParams(typedesc[T]).get(0)](data, itemBcs)

        var item : genericParams(typedesc[T]).get(0)
        deSerialize(itemBcs, item)

        result.add item

proc deSerializeArray*[T : array](data : string) : T =
    
    var data = data
    for pos in 0..<len(T):

        var itemBcs : string
        tokenize[genericParams(typedesc[T]).get(1)](data, itemBcs)

        var item : genericParams(typedesc[T]).get(1)
        deSerialize(itemBcs, item)

        result[pos] = item

proc deSerializeTuple*[T : tuple](data : string) : T =
    
    var data = data
    for val in fields(result):

        var itemBcs : string
        tokenize[typeof(val)](data, itemBcs)

        var item : typeof(val)
        deSerialize(itemBcs, item)

        val = item

proc deSerializeObj*[T : object | ref object](data : string) : T =
    
    var data = data
    when T is ref object:

        var refResultSub : T 
        new(refResultSub)
        var resultSub = refResultSub[]

    elif T is object:

        var resultSub : T

    for field in fields(resultSub):

        var itemBcs : string
        tokenize[typeof(field)](data, itemBcs)

        deSerialize(itemBcs, field)
    
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

proc deSerializeHashTable*[T : CountTable | CountTableRef | OrderedTable | OrderedTableRef | Table | TableRef](data : string) : T =

    when T is CountTable or T is CountTableRef:

        let tableLen = strutils.fromHex[uint64](data[0..15])
        var data = data[16..^1]
        for _ in 0..<tableLen:

            var 
                itemBcs : string
                newOutput : string
            tokenize[genericParams(typedesc[T]).get(0)](data, newOutput)
            itemBcs.add newOutput

            newOutput = ""
            tokenize[int](data, newOutput)
            itemBcs.add newOutput

            var item : tuple[key : genericParams(typedesc[T]).get(0), val : int]
            deSerialize(itemBcs, item)

            result[item[0]] = item[1]

    else:

        let tableLen = strutils.fromHex[uint64](data[0..15])
        var data = data[16..^1]
        for _ in 0..<tableLen:

            var 
                itemBcs : string
                newOutput : string
            tokenize[genericParams(typedesc[T]).get(0)](data, newOutput)
            itemBcs.add newOutput

            newOutput = ""
            tokenize[genericParams(typedesc[T]).get(1)](data, newOutput)
            itemBcs.add newOutput

            var item : tuple[key : genericParams(typedesc[T]).get(0), val : genericParams(typedesc[T]).get(1)]
            deSerialize(itemBcs, item)

            result[item[0]] = item[1]

proc deSerializeOption*[T : Option](data : string) : T =

    if data == "00":

        return none[genericParams(typedesc[T]).get(0)]()

    else:
        
        if data[0..1] != "01":

            raise newException(InvalidBcsStructure, "option type structure is invalid")
        
        var optionValue : genericParams(typedesc[T]).get(0)
        when genericParams(typedesc[T]).get(0) is ref object:

            new(optionValue)

        result = some(optionValue)
        deSerialize(data[2..^1], result.get())

