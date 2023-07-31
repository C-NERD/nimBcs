import std / [unittest, tables, options]
import bcs

type

  TestEnum = enum

    TakeOne, TakeTwo

  TestObj = object

    test_int : int
    test_int128 : int128
    test_uint128 : uint128
    test_string : string
    test_bool : bool
    test_enum : TestEnum
    test_seq : seq[int32]
    test_array : array[5, string]
    test_tuple : tuple[sir, boss : string, hello : int]
    #rec_obj : ref TestObj
    test_table : OrderedTable[string, string]
    test_option : Option[seq[int16]]

suite "bcs serialization and deserialization test":
  
  #var refTestObj : ref TestObj 
  #new(refTestObj)
  let 
    testTable = toOrderedTable[string, string]([("Hello", "world"), ("Hi", "Nim")])
    testObj = TestObj(
      test_int : 5,
      test_int128 : -3472392302429482492'i128,
      test_uint128 : 734982023919232042382'u128,
      test_string : "test",
      test_bool : true,
      test_enum : TakeTwo,
      test_seq : @[5'i32, 18'i32, 8'i32],
      test_array : ["testing", "this", "object", "hope", "it works"],
      test_tuple : ("Hello", "world", 5),
      #rec_obj : refTestObj,
      test_table : testTable,
      test_option : some(@[6'i16, 12'i16])
    )
  var bcs : string
  test "serialization test":
    
    var refTestObj : ref TestObj
    new(refTestObj)
    
    refTestObj[] = testObj
    serialize(refTestObj, bcs)

  test "deserialization test":

    var refTestObj : ref TestObj
    new(refTestObj)

    deSerialize(bcs, refTestObj)
    check refTestObj[] == testObj
     
