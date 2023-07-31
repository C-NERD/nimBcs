const Is64Bit* : bool = block:

    var is64 : bool = false
    if high(int) == high(int64):

        is64 = true

    is64

func switchByteOrder*(data : string) : string =
    ## switches hex byte order from 'little' to 'big'
    ## and vice versa.

    let dataLen = len(data)
    if (dataLen mod 2) != 0:

        raise newException(IndexDefect, "Invalid hex data, data len is not divisible by 2")

    for pos in countdown(len(data) - 1, 0, 2):

        result.add data[pos - 1..pos]
