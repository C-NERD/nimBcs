from std / strutils import fromHex, removePrefix, HexDigits

type 
    HexString* = distinct string

    InvalidHex* = object of ValueError

proc `$`*(x : HexString) : string {. borrow .}

proc len*(x : HexString) : int {. borrow .}

proc add*(x : var HexString, y : HexString) {. borrow .}

func fromHex[T : SomeInteger](data : HexString) : T = fromHex[T]($data)

func removePrefix(s : var HexString, y : string) {. borrow .}

proc `[]`*[T, U: Ordinal](s: HexString; x: HSlice[T, U]): HexString =

    var data = string(s)
    data = data[x]
    return HexString(data)

template isValidHex(data : HexString) : untyped =
    
    var cond = false
    if (len(data) mod 2) != 0:

        cond = false

    else:

        cond = true
    
    for each in $data:

        if each notin HexDigits:

            cond = false
            break

    cond

converter fromString*(data : string) : HexString =
    
    var data = HexString(data)
    removePrefix(data, "0x")
    if not isValidHex(data):

        raise newException(InvalidHex, "Invalid hex data")

    return data

converter toBytes*(data : HexString) : seq[byte] =
    
    ## checks are done when converting string to HexString
    ## so no need for checks
    for pos in countup(0, len(data) - 1, 2):
        
        let oneByte = data[pos..(pos + 1)]
        result.add fromHex[byte](oneByte)

func switchByteOrder*(data : HexString) : HexString =
    ## switches hex byte order from 'little' to 'big'
    ## and vice versa.
    
    if not isValidHex(data) : raise newException(InvalidHex, "Invalid hex data")
    for pos in countdown(len(data) - 1, 0, 2):

        result.add data[pos - 1..pos]

