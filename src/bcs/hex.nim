type 
    HexString* = distinct string

    InvalidHex* = object of ValueError

proc `$`*(x : HexString) : string {. borrow .}

proc len*(x : HexString) : int {. borrow .}

proc add*(x : var HexString, y : HexString) {. borrow .}

proc `[]`*[T, U: Ordinal](s: HexString; x: HSlice[T, U]): HexString =

    var data = string(s)
    data = data[x]
    return HexString(data)

template isValidHex(data : HexString) : untyped =
    
    if (len(data) mod 2) != 0:

        false

    else:

        true

converter fromString*(data : string) : HexString =
    
    let data = HexString(data)
    if not isValidHex(data):

        raise newException(InvalidHex, "Invalid hex data")

    return data

proc toBytes*(data : HexString) : seq[byte] =

    discard

func switchByteOrder*(data : HexString) : HexString =
    ## switches hex byte order from 'little' to 'big'
    ## and vice versa.
    
    if not isValidHex(data) : raise newException(InvalidHex, "Invalid hex data")
    for pos in countdown(len(data) - 1, 0, 2):

        result.add data[pos - 1..pos]
