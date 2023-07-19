#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
from std / strformat import fmt
from std / strutils import parseInt

when not defined(js):
    
    import pkg / integers

    type

        int128* = object 

            value : Integer ## caps value at 170141183460469231731687303715884105727
        ## and allows for -ve value
        uint128* = object 

            value : Integer ## caps value at 340282366920938463463374607431768211455
        ## and does not allow for -ve value 

    template `int`(data : Integer) : untyped = parseInt($data)

else:

    import std / jsbigints

    type

        int128* = object 

            value : JsBigInt

        uint128* = object

            value : JsBigInt

    template `int`(data : JsBigInt) : untyped = parseInt($toCstring(data))

    template parseStrInt(data : string) : untyped =

        var rData : string
        for item in data:

            if item in {'0'..'9', 'A'..'F', 'a'..'f', '-', 'o', 'x', '.'}:

                rData.add item

        rData

const HexChars = "0123456789ABCDEF"
converter `$`*(data : int128) : string = 
    
    when not defined(js):
        
        `$`(data.value)

    else:

        $(toCstring(data.value))

converter `$`*(data : uint128) : string = 
    
    when not defined(js):
        
        `$`(data.value)

    else:

        $(toCstring(data.value))

template padHex(data : var string) : untyped =
    
    let dataLen = len(data)
    if dataLen < 32:

        for _ in 1..(32 - dataLen):

            data = "0" & data

    elif dataLen > 32:

        raise newException(RangeDefect, "the hex data is greater than 32 characters")

    data

template rmHexPadding(data : string)  : untyped =
    
    var dataTmpl = data
    let dataLen = len(data)
    for pos in 0..<dataLen:

        if data[pos] == '0':

            if dataLen - 1 == pos:

                break ## if all character are '0' stop at last char

            dataTmpl = dataTmpl[1..^1]

        elif data[pos] != '0':

            break
    
    dataTmpl

#[template addHexPrefix(data : var string) : untyped =

    if data[0..1] != "0x":

        data = "0x" & data

    data]#

template rmHexPrefix(data : var string) : untyped =
    
    if len(data) > 2:

        if data[0..1] == "0x":

            data = data[2..^1]

    data

proc `==`*(x, y : int128) : bool = x.value == y.value

proc `==`*(x, y : uint128) : bool = x.value == y.value

proc high*[T : int128 | uint128](_ : typedesc[T]) : T =

    when T is int128:

        when not defined(js):

            result.value = 170141183460469231731687303715884105727'gmp

        else:

            result.value = 170141183460469231731687303715884105727'big

    elif T is uint128:

        when not defined(js):

            result.value = 340282366920938463463374607431768211455'gmp

        else:

            result.value = 340282366920938463463374607431768211455'big

proc low*[T : int128 | uint128](_ : typedesc[T]) : T =

    when T is int128:

        when not defined(js):

            result.value = -170141183460469231731687303715884105727'gmp

        else:

            result.value = -170141183460469231731687303715884105727'big

    elif T is uint128:

        when not defined(js):

            result.value = 0'gmp

        else:

            result.value = 0'big

proc sizeof*[T : int128 | uint128](_ : typedesc[T]) : T = 
    
    when T is int128:

        16'i128

    elif T is uint128:

        16'u128

proc newInt128*(data : string) : int128 =
    
    when not defined(js):
            
        result.value = newInteger(data)
        if result.value > high(int128).value or result.value < low(int128).value:

            raise newException(RangeDefect, fmt"{result} is not within the range {low(int128)} and {high(int128)}")

    else:
        
        result.value = big(cstring(parseStrInt(data)))
        if result.value > high(int128).value or result.value < low(int128).value:

            raise newException(RangeDefect, fmt"{result} is not within the range {low(int128)} and {high(int128)}")

proc newUInt128*(data : string) : uint128 =
    
    when not defined(js):
            
        result.value = newInteger(data)
        if result.value > high(uint128).value or result.value < low(uint128).value:

            raise newException(RangeDefect, fmt"{result} is not within the range {low(uint128)} and {high(uint128)}")

    else:
        
        result.value = big(cstring(parseStrInt(data)))
        if result.value > high(uint128).value or result.value < low(uint128).value:

            raise newException(RangeDefect, fmt"{result} is not within the range {low(uint128)} and {high(uint128)}")

template `'i128`*(data : string) : untyped = newInt128(data)

template `'u128`*(data : string) : untyped = newUInt128(data)

proc toHex*(data : int128) : string =
    
    var data = data.value
    if data == (0'i128).value:

        var resultHex1 = "0"
        return padHex(resultHex1)

    if data < (0'i128).value:

        let shiftValue = (1'i128).value shl (128'i128).value
        data = shiftValue + data
    
    while data > (0'i128).value:
        
        let 
            modulo = data mod (16'i128).value
            hex_digit = HexChars[int(modulo)]

        result = hex_digit & result
        data = data div (16'i128).value
    
    var resultHex2 = result
    return padHex(resultHex2)

proc toHex*(data : uint128) : string =
    
    var data = data.value
    if data == (0'u128).value:

        var resultHex1 = "0"
        return padHex(resultHex1)

    while data > (0'u128).value:
        
        let 
            modulo = data mod (16'u128).value
            hex_digit = HexChars[int(modulo)]

        result = hex_digit & result
        data = data div (16'u128).value
    
    var resultHex2 = result
    return padHex(resultHex2)

proc fromHex*[T : int128 | uint128](data : string) : T =
    
    var data = data
    data = rmHexPrefix(data)
    data = rmHexPadding(data)
    var 
        foundDigit = false
        i = 0
        output = (0'u128).value
    let last = len(data)
    if (i + 1) < last and data[i] == '0' and (data[i + 1] in {'x', 'X'}): inc(i, 2)
    elif i < last and data[i] == '#': inc(i)
    while i < last:

        case data[i]

        of '_': discard

        of '0'..'9':

          output = output shl (4'u128).value or newUInt128($(ord(data[i]) - ord('0'))).value
          foundDigit = true

        of 'a'..'f':

          output = output shl (4'u128).value or newUInt128($(ord(data[i]) - ord('a') + 10)).value
          foundDigit = true

        of 'A'..'F':

          output = output shl (4'u128).value or newUInt128($(ord(data[i]) - ord('A') + 10)).value
          foundDigit = true

        else: break
        inc(i)

    if foundDigit:

        result.value = output
        when T is int128:
            
            if result.value > (high(int128)).value:

                let 
                    shiftValue = (1'i128).value shl (128'i128).value
                    intValue = result.value - shiftValue
                if intValue < (0'i128).value:

                    result.value = intValue

when isMainModule:

    let 
        num = 170141183460469231731687303715884105727'i128
        numHex = toHex(num)
    
    echo numHex
    echo fromHex[int128](numHex)

