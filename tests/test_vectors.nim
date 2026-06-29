import std / [unittest, options]
from std / strutils import toHex
import bcs

## Byte-level BCS spec vectors.
##
## The round-trip tests in test1.nim only prove that `serializeBytes` and
## `deSerializeBytes` are inverses of each other -- they pass even when both
## sides share the same wrong convention (e.g. big-endian integers). These
## vectors pin the wire format to the BCS spec (little-endian, ULEB128 lengths)
## so a regression in byte order is caught immediately.

proc hx(s: seq[byte]): string =
  for b in s: result.add b.toHex

type
  EnumVec {.pure.} = enum First, Second, Third
  HoledEnum = enum HoA = 5, HoB = 9, HoC = 11 # ord != position
  StrEnum = enum SeRed = "red", SeGreen = "green", SeBlue = "blue"

suite "bcs spec vectors (wire format)":

  test "unsigned integers are little-endian":
    check hx(serializeBytes[uint8](255'u8)) == "FF"
    check hx(serializeBytes[uint16](258'u16)) == "0201" # 0x0102 LE
    check hx(serializeBytes[uint32](1'u32)) == "01000000"
    check hx(serializeBytes[uint64](1'u64)) == "0100000000000000"
    check hx(serializeBytes[uint32](305419896'u32)) == "78563412" # 0x12345678 LE
    check hx(serializeBytes[uint64](high(uint64))) == "FFFFFFFFFFFFFFFF"

  test "signed integers are two's-complement little-endian":
    check hx(serializeBytes[int8](-1'i8)) == "FF"
    check hx(serializeBytes[int32](-1'i32)) == "FFFFFFFF"
    check hx(serializeBytes[int64](-2'i64)) == "FEFFFFFFFFFFFFFF"

  test "bool / string / option / seq":
    check hx(serializeBytes[bool](true)) == "01"
    check hx(serializeBytes[bool](false)) == "00"
    # ULEB128 length 0x0b then ascii bytes
    check hx(serializeBytes[string]("Hello world")) == "0B48656C6C6F20776F726C64"
    check hx(serializeBytes[Option[uint32]](none(uint32))) == "00"
    check hx(serializeBytes[Option[uint32]](some(1'u32))) == "0101000000"
    check hx(serializeBytes[seq[uint8]](@[1'u8, 2, 3])) == "03010203"

  test "round trips":
    var a = serializeBytes[uint64](123456789'u64)
    check deSerializeBytes[uint64](a) == 123456789'u64

    var b = serializeBytes[int64](-987654321'i64)
    check deSerializeBytes[int64](b) == -987654321'i64

  test "empty string / seq / option deserialize without underflow":
    # Regression: a uint32 length of 0 used to underflow to ~4e9 in the
    # `len - 1` slice bound, crashing on every empty string or vector.
    check hx(serializeBytes[string]("")) == "00"
    block:
      var w = serializeBytes[string]("")
      check deSerializeBytes[string](w) == ""
    block:
      let empty: seq[uint8] = @[]
      var w = serializeBytes[seq[uint8]](empty)
      check deSerializeBytes[seq[uint8]](w).len == 0
    block:
      let s: seq[string] = @["", "a", "", "abc"]
      var w = serializeBytes[seq[string]](s)
      check deSerializeBytes[seq[string]](w) == s

  test "vector<u8> is a ULEB128 length prefix plus raw bytes":
    # The BCS bytes type is just seq[uint8]/seq[byte].
    let bytesVal: seq[uint8] = @[0xAA'u8, 0xBB, 0xCC]
    check hx(serializeBytes[seq[uint8]](bytesVal)) == "03AABBCC"
    block:
      var w = serializeBytes[seq[uint8]](bytesVal)
      check deSerializeBytes[seq[uint8]](w) == bytesVal
    block: # empty vector<u8>
      let empty: seq[uint8] = @[]
      var w = serializeBytes[seq[uint8]](empty)
      check deSerializeBytes[seq[uint8]](w).len == 0

  test "enum is a bare ULEB128 variant index (no string name)":
    # Regression: enums used to be serialized as index + the variant name.
    # Standard BCS encodes only the ULEB128 variant index.
    check hx(serializeBytes[EnumVec](First)) == "00"
    check hx(serializeBytes[EnumVec](Second)) == "01"
    check hx(serializeBytes[EnumVec](Third)) == "02"
    block:
      var w = serializeBytes[EnumVec](Third)
      check deSerializeBytes[EnumVec](w) == Third
    block: # out-of-range index must be rejected, not silently coerced
      var bad: seq[byte] = @[7'u8]
      expect InvalidBcsStructure:
        discard deSerializeBytes[EnumVec](bad)

  test "enum index is variant position, not ord (holed + string enums)":
    # Holed enum: ord(HoA)=5 but its variant index must be 0.
    check hx(serializeBytes[HoledEnum](HoA)) == "00"
    check hx(serializeBytes[HoledEnum](HoB)) == "01"
    check hx(serializeBytes[HoledEnum](HoC)) == "02"
    # String-valued enum encodes by position, name is recovered from the type.
    check hx(serializeBytes[StrEnum](SeGreen)) == "01"
    check hx(serializeBytes[StrEnum](SeBlue)) == "02"
    block:
      var w = serializeBytes[HoledEnum](HoC)
      check deSerializeBytes[HoledEnum](w) == HoC
    block:
      var w = serializeBytes[StrEnum](SeBlue)
      check deSerializeBytes[StrEnum](w) == SeBlue
    block: # index 3 is past the last variant -> rejected
      var bad: seq[byte] = @[3'u8]
      expect InvalidBcsStructure:
        discard deSerializeBytes[HoledEnum](bad)
