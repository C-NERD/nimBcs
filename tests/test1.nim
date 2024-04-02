import std / [unittest, tables, options]
import bcs

type

  TestEnum {.pure.} = enum

    TakeOne, TakeTwo

suite "bcs serialization and deserialization test": 
    
  test "serializing int":
    
    let ogData : int = high(int)
    var 
      bcs : HexString
      data : int
    serialize[int](ogData, bcs)
    deserialize[int](bcs, data)

    check ogData == data

  test "serializing int128":

    let ogData : int128 = high(int128)
    var
      bcs : HexString
      data : int128
    serialize[int128](ogData, bcs)
    deserialize[int128](bcs, data)

    check ogData == data

  test "serializing int256":

    let ogData : int256 = high(int256)
    var
      bcs : HexString
      data : int256
    serialize[int256](ogData, bcs)
    deserialize[int256](bcs, data)

    check ogData == data

  test "serializing string":

    let ogData : string = "Hello world"
    var
      bcs : HexString
      data : string
    serialize[string](ogData, bcs)
    deserialize[string](bcs, data)

    check ogData == data

  test "serializing enum":

    let ogData : TestEnum = TakeTwo
    var
      bcs : HexString
      data : TestEnum
    serialize[TestEnum](ogData, bcs)
    deserialize[TestEnum](bcs, data)

    check ogData == data

  test "serializing bool":

    let ogData : bool = false
    var
      bcs : HexString
      data : bool
    serialize[bool](ogData, bcs)
    deserialize[bool](bcs, data)

    check ogData == data

  test "serializing seq":

    let ogData : seq[int] = @[10, 20, 30, 40, 50]
    var
      bcs : HexString
      data : seq[int]
    serialize[seq[int]](ogData, bcs)
    deserialize[seq[int]](bcs, data)

    check ogData == data

  test "serializing array":

    let ogData : array[2, string] = ["lib", "update"]
    var
      bcs : HexString
      data : array[2, string]
    serialize[array[2, string]](ogData, bcs)
    deserialize[array[2, string]](bcs, data)

    check ogData == data

  test "serializing tuple":

    let ogData : tuple[first : int32, second : int64, third : int128, fourth : int256] = (23'i32, 23'i64, 23'i128, 23'i256)
    var
      bcs : HexString
      data : tuple[first : int32, second : int64, third : int128, fourth : int256] = (0'i32, 0'i64, 0'i128, 0'i256)
    serialize[tuple[first : int32, second : int64, third : int128, fourth : int256]](ogData, bcs)
    deserialize[tuple[first : int32, second : int64, third : int128, fourth : int256]](bcs, data)

    check ogData == data

  test "serializing option":

    let ogData : Option[string] = some("I am ok")
    var
      bcs : HexString
      data : Option[string]
    serialize[Option[string]](ogData, bcs)
    deserialize[Option[string]](bcs, data)

    check ogData == data

  test "serializing table":

    let ogData : OrderedTable[string, string] = toOrderedTable[string, string]([("Hello", "world"), ("Hi", "Nim")])
    var
      bcs : HexString
      data : OrderedTable[string, string]
    serialize[OrderedTable[string, string]](ogData, bcs)
    deserialize[OrderedTable[string, string]](bcs, data)

    check ogData == data

