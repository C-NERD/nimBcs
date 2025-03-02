import std / [unittest, tables, options]
import bcs

type

  TestEnum {.pure.} = enum

    TakeOne, TakeTwo

suite "bcs serialization and deserialization test":

  test "serializing int":

    let ogData: int = high(int)
    var
      bcs: HexString = serialize[int](ogData)
      data: int = deSerialize[int](bcs)

    check ogData == data

  test "serializing int128":

    let ogData: int128 = high(int128)
    var
      bcs: HexString = serialize[int128](ogData)
      data: int128 = deSerialize[int128](bcs)

    check ogData == data

  test "serializing int256":

    let ogData: int256 = high(int256)
    var
      bcs: HexString = serialize[int256](ogData)
      data: int256 = deSerialize[int256](bcs)

    check ogData == data

  test "serializing string":

    let ogData: string = "Hello world"
    var
      bcs: HexString = serialize[string](ogData)
      data: string = deSerialize[string](bcs)

    check ogData == data

  test "serializing enum":

    let ogData: TestEnum = TakeTwo
    var
      bcs: HexString = serialize[TestEnum](ogData)
      data: TestEnum = deSerialize[TestEnum](bcs)

    check ogData == data

  test "serializing bool":

    let ogData: bool = false
    var
      bcs: HexString = serialize[bool](ogData)
      data: bool = deSerialize[bool](bcs)

    check ogData == data

  test "serializing seq":

    let ogData: seq[int] = @[10, 20, 30, 40, 50]
    var
      bcs: HexString = serialize[seq[int]](ogData)
      data: seq[int] = deSerialize[seq[int]](bcs)

    check ogData == data

  test "serializing array":

    let ogData: array[2, string] = ["lib", "update"]
    var
      bcs: HexString = serialize[array[2, string]](ogData)
      data: array[2, string] = deSerialize[array[2, string]](bcs)

    check ogData == data

  test "serializing tuple":

    let ogData: tuple[first: int32, second: int64, third: int128,
        fourth: int256] = (23'i32, 23'i64, 23'i128, 23'i256)
    var
      bcs: HexString = serialize[tuple[first: int32, second: int64,
          third: int128, fourth: int256]](ogData)
      data: tuple[first: int32, second: int64, third: int128,
          fourth: int256] = deSerialize[tuple[first: int32, second: int64,
          third: int128, fourth: int256]](bcs)

    check ogData == data

  test "serializing option":

    let ogData: Option[string] = some("I am ok")
    var
      bcs: HexString = serialize[Option[string]](ogData)
      data: Option[string] = deSerialize[Option[string]](bcs)

    check ogData == data

  test "serializing table":

    let ogData: OrderedTable[string, string] = toOrderedTable[string, string]([(
        "Hello", "world"), ("Hi", "Nim")])
    var
      bcs: HexString = serialize[OrderedTable[string, string]](ogData)
      data: OrderedTable[string, string] = deSerialize[OrderedTable[string,
          string]](bcs)

    check ogData == data

