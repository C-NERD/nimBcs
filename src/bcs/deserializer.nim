#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
{.experimental: "codeReordering".}

from std / options import Option, none, some
from std / tables import CountTable, CountTableRef, OrderedTable,
        OrderedTableRef, Table, TableRef, `[]=`
from std / typetraits import genericParams, get
from std / bitops import bitand, bitor
from std / enumutils import items

import constants, byteops

export genericParams, get

## Library extensibility:
## To extend the function of this library to cover custom deSerialization procs,
## create a `fromBcsHookBytes` proc with params (x : var seq[byte], y : var T)
## with:
##    T = custom datatype to be deSerialized to
##
## example:
##    proc fromBcsHookBytes(x : var seq[byte], y : var Address) =
##        if x[0] == 0'u8:
##            y = initAddress("0x00")
##
## Note :: param `x` is required to be of type var seq[byte] as it is expected that
## once the bytes representing the data to be deserialized by the custom hook proc are processed,
## the bytes representing the data should be removed from the `x` variable leaving only
## undeserialized data
##
## Performance note :: internally, deserialization reads through a `pos` cursor
## (an offset into the buffer) and only advances it, so consuming a field is
## O(1). Re-slicing the remaining buffer after every field used to copy the
## tail and allocate on each step, making container deserialization O(n^2). The
## public procs below are thin wrappers: they run an internal `*At` worker from
## `pos = 0` and then drop the consumed prefix from the caller's buffer exactly
## once, preserving the documented "buffer is left with the undeserialized
## remainder" contract (so custom hooks keep working unchanged).

const Is64Bit*: bool =

    block:

        var is64: bool = false
        if high(int) == high(int64):

            is64 = true

        is64

    ## for checking if compilation enviroment is 64bit

# ---------------------------------------------------------------------------
# internal cursor-based ULEB128 reader
# ---------------------------------------------------------------------------

template takeUlebBytes*(data: seq[byte], pos: var int): uint32 =
    ## read a ULEB128 length from `data` at `pos`, advancing `pos`

    var value, shift: uint64
    while value <= high(uint32):

        let byteVal: byte = data[pos]
        pos += 1
        let digit = bitand(byteVal, 0x7F)
        value = bitor(value, uint64(digit) shl shift)
        if bitand(byteVal, 0x80) == 0:

            break

        shift.inc(7)

    uint32(value)

proc enumByVariantIndex*[T: enum](index: uint32): T =
    ## map a BCS variant index back to T's variant at that 0-based position,
    ## in declaration order (the inverse of `bcsVariantIndex`)

    var pos: uint32 = 0
    for variant in items(T):

        if pos == index: return variant

        inc pos

    raise newException(InvalidBcsStructure, "enum variant index is out of range")

# ---------------------------------------------------------------------------
# internal cursor-based dispatch (defined before the workers it calls)
# ---------------------------------------------------------------------------

template deSerBytesAt*[T](data: seq[byte], pos: var int): untyped =
    ## internal cursor-based dispatch for deserialization

    when T is CountTable or T is CountTableRef or T is OrderedTable or
        T is OrderedTableRef or T is Table or T is TableRef:

        deSerHashTableBytesAt[T](data, pos)

    elif T is Option:

        deSerOptionBytesAt[T](data, pos)

    elif T is int8 or T is uint8:

        var output: T
        when T is int8: output = cast[T](data[pos])
        else: output = data[pos]
        pos += 1
        output

    elif T is int16 or T is uint16:

        var bytes: seq[byte] = @[data[pos], data[pos + 1]]
        bytes = switchByteOrder(bytes)
        let byteArray: array[2, byte] = [bytes[0], bytes[1]]
        pos += 2
        cast[T](byteArray)

    elif T is int32 or T is uint32:

        var bytes: seq[byte] = @[data[pos], data[pos + 1], data[pos + 2], data[pos + 3]]
        bytes = switchByteOrder(bytes)
        let byteArray: array[4, byte] = [bytes[0], bytes[1], bytes[2], bytes[3]]
        pos += 4
        cast[T](byteArray)

    elif T is int64 or T is uint64:

        var bytes: seq[byte] = @[data[pos], data[pos + 1], data[pos + 2],
                data[pos + 3], data[pos + 4], data[pos + 5], data[pos + 6],
                data[pos + 7]]
        bytes = switchByteOrder(bytes)
        let byteArray: array[8, byte] = [bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7]]
        pos += 8
        cast[T](byteArray)

    elif T is int or T is uint:

        when Is64Bit:

            when T is int: int(deSerBytesAt[int64](data, pos))
            elif T is uint: uint(deSerBytesAt[uint64](data, pos))

        else:

            when T is int: int(deSerBytesAt[int32](data, pos))
            elif T is uint: uint(deSerBytesAt[uint32](data, pos))

    elif T is bool:

        deSerBoolBytesAt(data, pos)

    elif T is string:

        deSerStrBytesAt(data, pos)

    elif T is enum:

        enumByVariantIndex[T](takeUlebBytes(data, pos))

    elif T is seq:

        deSerSeqBytesAt[T](data, pos)

    elif T is array:

        deSerArrayBytesAt[T](data, pos)

    elif T is tuple:

        deSerTupleBytesAt[T](data, pos)

    else:

        var output: T
        var tail = data[pos .. ^1]
        when compiles(fromBcsHookBytes(tail, output)):

            fromBcsHookBytes(tail, output)
            pos = len(data) - len(tail)

        else:

            {.error: $T & " is not supported".}

        output

# ---------------------------------------------------------------------------
# internal cursor-based workers
# ---------------------------------------------------------------------------

template deSerBoolBytesAt*(data: seq[byte], pos: var int): bool =

    var res: bool
    let b = data[pos]
    pos += 1
    if b == 1'u8: res = true
    elif b == 0'u8: res = false
    else: raise newException(InvalidBcsStructure, "bool type structure is invalid")
    res

template deSerStrBytesAt*(data: seq[byte], pos: var int): string =

    let strLen: int = int(takeUlebBytes(data, pos))
    var res = newStringOfCap(strLen)
    for i in 0 ..< strLen:

        res.add cast[char](data[pos + i])

    pos += strLen
    res

template deSerSeqBytesAt*[T: seq](data: seq[byte], pos: var int): untyped =

    var seqOutput: T
    let seqLen: uint32 = takeUlebBytes(data, pos)
    for _ in 0 ..< seqLen:

        seqOutput.add deSerBytesAt[genericParams(typedesc[T]).get(0)](data, pos)

    seqOutput

template deSerArrayBytesAt*[T: array](data: seq[byte], pos: var int): untyped =

    var arrayOutput: T
    for idx in 0 ..< len(T):

        arrayOutput[idx] = deSerBytesAt[genericParams(typedesc[T]).get(1)](data, pos)

    arrayOutput

template deSerTupleBytesAt*[T: tuple](data: seq[byte], pos: var int): untyped =

    var tupleOutput: T
    for val in fields(tupleOutput):

        val = deSerBytesAt[typeof(val)](data, pos)

    tupleOutput

template deSerHashTableBytesAt*[T: CountTable | CountTableRef | OrderedTable |
        OrderedTableRef | Table | TableRef](data: seq[byte], pos: var int): untyped =

    var tableOutput: T
    let tableLen: uint32 = takeUlebBytes(data, pos)
    when T is CountTable or T is CountTableRef:

        for _ in 0 ..< tableLen:

            let key = deSerBytesAt[genericParams(typedesc[T]).get(0)](data, pos)
            let val = deSerBytesAt[int](data, pos)
            tableOutput[key] = val

    else:

        for _ in 0 ..< tableLen:

            let key = deSerBytesAt[genericParams(typedesc[T]).get(0)](data, pos)
            let val = deSerBytesAt[genericParams(typedesc[T]).get(1)](data, pos)
            tableOutput[key] = val

    tableOutput

template deSerOptionBytesAt*[T: Option](data: seq[byte], pos: var int): untyped =

    var optionOutput: T
    let tag = data[pos]
    pos += 1
    if tag == 0'u8:

        optionOutput = none[genericParams(typedesc[T]).get(0)]()

    elif tag == 1'u8:

        var optionValue: genericParams(typedesc[T]).get(0)
        when genericParams(typedesc[T]).get(0) is ref object:

            new(optionValue)

        optionValue = deSerBytesAt[typeof(optionValue)](data, pos)
        optionOutput = some(optionValue)

    else:

        raise newException(InvalidBcsStructure, "option type structure is invalid")

    optionOutput

# ---------------------------------------------------------------------------
# public API: thin wrappers that drop the consumed prefix exactly once
# ---------------------------------------------------------------------------

template deSerializeUleb128Bytes*(data: var seq[byte]): untyped =
    ## deserialize bcs data length

    var pos = 0
    let res = takeUlebBytes(data, pos)
    data = data[pos .. ^1]
    res

template deSerializeBytes*[T](data: var seq[byte]): untyped =
    ## deserialize template, for unified way of calling deserialization procs for all types

    var pos = 0
    let res = deSerBytesAt[T](data, pos)
    data = data[pos .. ^1]
    res

proc deSerializeBoolBytes*(data: var seq[byte]): bool =
    ## deserialize into nim's bool type

    var pos = 0
    result = deSerBoolBytesAt(data, pos)
    data = data[pos .. ^1]

proc deSerializeStrBytes*(data: var seq[byte]): string =
    ## deserialize into nim's string type

    var pos = 0
    result = deSerStrBytesAt(data, pos)
    data = data[pos .. ^1]

proc deSerializeEnumBytes*[T: enum](data: var seq[byte]): T =
    ## deserialize a BCS enum variant index (ULEB128) into nim's enum type

    var pos = 0
    result = enumByVariantIndex[T](takeUlebBytes(data, pos))
    data = data[pos .. ^1]

template deSerializeSeqBytes*[T: seq](data: var seq[byte]): untyped =
    ## deserialize into nim's seq type

    var pos = 0
    let res = deSerSeqBytesAt[T](data, pos)
    data = data[pos .. ^1]
    res

template deSerializeArrayBytes*[T: array](data: var seq[byte]): untyped =
    ## deserialize into nim's array type

    var pos = 0
    let res = deSerArrayBytesAt[T](data, pos)
    data = data[pos .. ^1]
    res

template deSerializeTupleBytes*[T: tuple](data: var seq[byte]): untyped =
    ## deserialize into nim's tuple type

    var pos = 0
    let res = deSerTupleBytesAt[T](data, pos)
    data = data[pos .. ^1]
    res

template deSerializeHashTableBytes*[T: CountTable | CountTableRef |
        OrderedTable | OrderedTableRef | Table | TableRef](data: var seq[
                byte]): untyped =
    ## deserialize into nim's table types

    var pos = 0
    let res = deSerHashTableBytesAt[T](data, pos)
    data = data[pos .. ^1]
    res

template deSerializeOptionBytes*[T: Option](data: var seq[byte]): untyped =
    ## deserialize into nim's option type

    var pos = 0
    let res = deSerOptionBytesAt[T](data, pos)
    data = data[pos .. ^1]
    res
