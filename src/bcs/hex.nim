#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.

from std / strutils import fromHex, toHex, removePrefix, HexDigits

import errors

## custom hex module implementation as alternative method for handling bytes with string operations

type
    HexString* = distinct string ## distint string representation of hex strings

proc `$`*(x: HexString): string {.borrow.} ## borrowed from strutils

proc len*(x: HexString): int {.borrow.} ## borrowed from strutils

proc byteLen*(x: HexString): int =
    ## length of byte represented

    int(len(x) / 2)

proc add*(x: var HexString, y: HexString) {.borrow.} ## borrowed from strutils

func removePrefix(s: var HexString, y: string) {.borrow.} ## borrowed from strutils

func fromBytes*(data: openArray[byte]): HexString =
    ## converts bytes to HexString

    for each in data:

        result.add HexString(toHex[byte](each))

proc `[]`*[T, U: Ordinal](s: HexString; x: HSlice[T, U]): HexString =
    ## slice operator for HexString

    var data = string(s)
    data = data[x]
    return HexString(data)

template isValidHex(data: HexString): untyped =
    ## checks if HexString is valid hex data

    var cond: bool = false
    if (len(data) mod 2) != 0:

        cond = false

    else:

        cond = true

    for each in $data:

        if each notin HexDigits:

            cond = false
            break

    cond

converter fromString*(data: string): HexString =
    ## converts normal nim string data to HexString

    var data: HexString = HexString(data)
    removePrefix(data, "0x")
    if not isValidHex(data):

        raise newException(InvalidHex, "Invalid hex data")

    return data

converter toBytes*(data: HexString): seq[byte] =
    ## checks are done when converting string to HexString
    ## so no need for checks

    for pos in countup(0, len(data) - 1, 2):

        let oneByte: HexString = data[pos..(pos + 1)]
        result.add fromHex[byte]($oneByte)

func switchByteOrder*(data: HexString): HexString =
    ## switches hex byte order from 'little' to 'big'
    ## and vice versa.

    if not isValidHex(data): raise newException(InvalidHex, "Invalid hex data")
    for pos in countdown(len(data) - 1, 0, 2):

        result.add data[pos - 1..pos]

