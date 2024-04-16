#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##   Emergency int128, uint128, int256 and uint256 implementation for the bcs library.
##   When these ints arrive to nim this module will be modified to accomodate
##   them or be scraped completly.
from std / strformat import fmt
from std / strutils import parseInt

import hex

when not defined(js):
    
    import pkg / integers

    type

        int128* = object 

            value : Integer ## caps value at 170141183460469231731687303715884105727
        ## and allows for -ve value
        uint128* = object 

            value : Integer ## caps value at 340282366920938463463374607431768211455
        ## and does not allow for -ve value 

        int256* = object

            value : Integer

        uint256* = object

            value : Integer

    template `int`(data : Integer) : untyped = parseInt($data)

    proc `<=`*(x, y : int128 | uint128 | int256 | uint256) : bool =

        x.value <= y.value

    proc `<`*(x, y : int128 | uint128 | int256 | uint256) : bool =

        x.value < y.value

else:

    import std / jsbigints

    type

        int128* = object 

            value : JsBigInt

        uint128* = object

            value : JsBigInt

        int256* = object

            value : JsBigInt

        uint256* = object

            value : JsBigInt

    template `int`(data : JsBigInt) : untyped = parseInt($toCstring(data))

    template parseStrInt(data : string) : untyped =

        var rData : string
        for item in data:

            if item in {'0'..'9', 'A'..'F', 'a'..'f', '-', 'o', 'x', '.'}:

                rData.add item

        rData

    proc `<=`*(x, y : int128 | uint128 | int256 | uint256) : bool =

        x.value <= y.value

    proc `<`*(x, y : int128 | uint128 | int256 | uint256) : bool =

        x.value < y.value

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

converter `$`*(data : int256) : string = 
    
    when not defined(js):
        
        `$`(data.value)

    else:

        $(toCstring(data.value))

converter `$`*(data : uint256) : string = 
    
    when not defined(js):
        
        `$`(data.value)

    else:

        $(toCstring(data.value))

template pad128Hex(data : var string) : untyped =
    
    let dataLen = len(data)
    if dataLen < 32:

        for _ in 1..(32 - dataLen):

            data = "0" & data

    elif dataLen > 32:

        raise newException(InvalidHex, "the hex data is greater than 32 characters")

    data

template pad256Hex(data : var string) : untyped =
    
    let dataLen = len(data)
    if dataLen < 64:

        for _ in 1..(64 - dataLen):

            data = "0" & data

    elif dataLen > 64:

        raise newException(InvalidHex, "the hex data is greater than 64 characters")

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

template rmHexPrefix(data : var string) : untyped =
    
    if len(data) > 2:

        if data[0..1] == "0x":

            data = data[2..^1]

    data

proc `==`*(x, y : int128) : bool = x.value == y.value

proc `==`*(x, y : uint128) : bool = x.value == y.value

proc `==`*(x, y : int256) : bool = x.value == y.value

proc `==`*(x, y : uint256) : bool = x.value == y.value

proc high*[T : int128 | uint128 | int256 | uint256](_ : typedesc[T]) : T =

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

    elif T is int256:

        when not defined(js):

            result.value = 57896044618658097711785492504343953926634992332820282019728792003956564819967'gmp

        else:

            result.value = 57896044618658097711785492504343953926634992332820282019728792003956564819967'big

    elif T is uint256:

        when not defined(js):

            result.value = 115792089237316195423570985008687907853269984665640564039457584007913129639935'gmp

        else:

            result.value = 115792089237316195423570985008687907853269984665640564039457584007913129639935'big

proc low*[T : int128 | uint128 | int256 | uint256](_ : typedesc[T]) : T =

    when T is int128:

        when not defined(js):

            result.value = -170141183460469231731687303715884105727'gmp

        else:

            result.value = -170141183460469231731687303715884105727'big

    elif T is uint128 or T is uint256:

        when not defined(js):

            result.value = 0'gmp

        else:

            result.value = 0'big

    elif T is int256:

        when not defined(js):

            result.value = -57896044618658097711785492504343953926634992332820282019728792003956564819967'gmp

        else:

            result.value = -57896044618658097711785492504343953926634992332820282019728792003956564819967'big

proc sizeof*[T : int128 | uint128 | int256 | uint256](_ : typedesc[T]) : T = 
    
    when T is int128:

        16'i128

    elif T is uint128:

        16'u128

    elif T is int256:

        32'i256

    elif T is uint256:

        32'u256

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

proc newInt256*(data : string) : int256 =
    
    when not defined(js):
            
        result.value = newInteger(data)
        if result.value > high(int256).value or result.value < low(int256).value:

            raise newException(RangeDefect, fmt"{result} is not within the range {low(int256)} and {high(int256)}")

    else:
        
        result.value = big(cstring(parseStrInt(data)))
        if result.value > high(int256).value or result.value < low(int256).value:

            raise newException(RangeDefect, fmt"{result} is not within the range {low(int256)} and {high(int256)}")

proc newUInt256*(data : string) : uint256 =
    
    when not defined(js):
            
        result.value = newInteger(data)
        if result.value > high(uint256).value or result.value < low(uint256).value:

            raise newException(RangeDefect, fmt"{result} is not within the range {low(uint256)} and {high(uint256)}")

    else:
        
        result.value = big(cstring(parseStrInt(data)))
        if result.value > high(uint256).value or result.value < low(uint256).value:

            raise newException(RangeDefect, fmt"{result} is not within the range {low(uint256)} and {high(uint256)}")

template `'i128`*(data : string) : untyped = newInt128(data)

template `'u128`*(data : string) : untyped = newUInt128(data)

template `'i256`*(data : string) : untyped = newInt256(data)

template `'u256`*(data : string) : untyped = newUInt256(data)

proc toHex*(data : int128) : string =
    
    var data = data.value
    if data == (0'i128).value:

        var resultHex1 = "0"
        return pad128Hex(resultHex1)

    if data < (0'i128).value:

        let shiftValue = (1'i128).value shl (128'i128).value
        data = shiftValue + data
    
    var resultHex2 : string
    while data > (0'i128).value:
        
        let 
            modulo = data mod (16'i128).value
            hex_digit = HexChars[int(modulo)]

        resultHex2 = hex_digit & resultHex2
        data = data div (16'i128).value
    
    resultHex2 = pad128Hex(resultHex2)
    return resultHex2

proc toHex*(data : uint128) : string =
    
    var data = data.value
    if data == (0'u128).value:

        var resultHex1 = "0"
        return pad128Hex(resultHex1)
    
    var resultHex2 : string
    while data > (0'u128).value:
        
        let 
            modulo = data mod (16'u128).value
            hex_digit = HexChars[int(modulo)]

        resultHex2 = hex_digit & resultHex2
        data = data div (16'u128).value
    
    resultHex2 = pad128Hex(resultHex2)
    return resultHex2

proc toHex*(data : int256) : string =
    
    var data = data.value
    if data == (0'i256).value:

        var resultHex1 = "0"
        return pad256Hex(resultHex1)

    if data < (0'i256).value:

        let shiftValue = (1'i256).value shl (256'i256).value
        data = shiftValue + data
    
    var resultHex2 : string
    while data > (0'i256).value:
        
        let 
            modulo = data mod (16'i256).value
            hex_digit = HexChars[int(modulo)]

        resultHex2 = hex_digit & resultHex2
        data = data div (16'i256).value
    
    resultHex2 = pad256Hex(resultHex2)
    return resultHex2

proc toHex*(data : uint256) : string =
    
    var data = data.value
    if data == (0'u256).value:

        var resultHex1 = "0"
        return pad256Hex(resultHex1)
    
    var resultHex2 : string
    while data > (0'u256).value:
        
        let 
            modulo = data mod (16'u256).value
            hex_digit = HexChars[int(modulo)]

        resultHex2 = hex_digit & resultHex2
        data = data div (16'u256).value
    
    resultHex2 = pad256Hex(resultHex2)
    return resultHex2

proc fromHex*[T : int128 | uint128 | int256 | uint256](data : string) : T =
    
    when T is int128 or T is uint128:

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
    
    elif T is int256 or T is uint256:
    
        var data = data
        data = rmHexPrefix(data)
        data = rmHexPadding(data)
        var 
            foundDigit = false
            i = 0
            output = (0'u256).value
        let last = len(data)
        if (i + 1) < last and data[i] == '0' and (data[i + 1] in {'x', 'X'}): inc(i, 2)
        elif i < last and data[i] == '#': inc(i)
        while i < last:

            case data[i]

            of '_': discard

            of '0'..'9':

              output = output shl (4'u256).value or newUInt128($(ord(data[i]) - ord('0'))).value
              foundDigit = true

            of 'a'..'f':

              output = output shl (4'u256).value or newUInt128($(ord(data[i]) - ord('a') + 10)).value
              foundDigit = true

            of 'A'..'F':

              output = output shl (4'u256).value or newUInt128($(ord(data[i]) - ord('A') + 10)).value
              foundDigit = true

            else: break
            inc(i)

        if foundDigit:

            result.value = output
            when T is int256:
                
                if result.value > (high(int256)).value:

                    let 
                        shiftValue = (1'i256).value shl (256'i256).value
                        intValue = result.value - shiftValue
                    if intValue < (0'i256).value:

                        result.value = intValue

when isMainModule:

    let 
        num = high(int256)
        numHex = toHex(num)
    
    echo numHex
    echo fromHex[int256](numHex)

