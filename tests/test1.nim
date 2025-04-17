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

    let ogData: tuple[first: int32, second: int64] = (23'i32, 23'i64)
    var
      bcs: HexString = serialize[tuple[first: int32, second: int64]](ogData)
      data: tuple[first: int32, second: int64] = deSerialize[tuple[first: int32,
          second: int64]](bcs)

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

suite "bcs bytes serialization and deserialization test":

  test "byte serializing int":

    let ogData: int = high(int)
    var
      bcs: seq[byte] = serializeBytes[int](ogData)
      data: int = deSerializeBytes[int](bcs)

    check ogData == data

  test "byte serializing string":

    let ogData: string = "Hello world"
    var
      bcs: seq[byte] = serializeBytes[string](ogData)
      data: string = deSerializeBytes[string](bcs)

    check ogData == data

  test "byte serializing enum":

    let ogData: TestEnum = TakeTwo
    var
      bcs: seq[byte] = serializeBytes[TestEnum](ogData)
      data: TestEnum = deSerializeBytes[TestEnum](bcs)

    check ogData == data

  test "byte serializing bool":

    let ogData: bool = false
    var
      bcs: seq[byte] = serializeBytes[bool](ogData)
      data: bool = deSerializeBytes[bool](bcs)

    check ogData == data

  test "byte serializing seq":

    let ogData: seq[int] = @[10, 20, 30, 40, 50]
    var
      bcs: seq[byte] = serializeBytes[seq[int]](ogData)
      data: seq[int] = deSerializeBytes[seq[int]](bcs)

    check ogData == data

  test "byte serializing array":

    let ogData: array[2, string] = ["lib", "update"]
    var
      bcs: seq[byte] = serializeBytes[array[2, string]](ogData)
      data: array[2, string] = deSerializeBytes[array[2, string]](bcs)

    check ogData == data

  test "byte serializing tuple":

    let ogData: tuple[first: int32, second: int64] = (23'i32, 23'i64)
    var
      bcs: seq[byte] = serializeBytes[tuple[first: int32, second: int64]](ogData)
      data: tuple[first: int32, second: int64] = deSerializeBytes[tuple[
          first: int32, second: int64]](bcs)

    check ogData == data

  test "byte serializing option":

    let ogData: Option[string] = some("I am ok")
    var
      bcs: seq[byte] = serializeBytes[Option[string]](ogData)
      data: Option[string] = deSerializeBytes[Option[string]](bcs)

    check ogData == data

  test "byte serializing table":

    let ogData: OrderedTable[string, string] = toOrderedTable[string, string]([(
        "Hello", "world"), ("Hi", "Nim")])
    var
      bcs: seq[byte] = serializeBytes[OrderedTable[string, string]](ogData)
      data: OrderedTable[string, string] = deSerializeBytes[OrderedTable[string,
          string]](bcs)

    check ogData == data


