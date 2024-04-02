#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
from std / tables import CountTable, CountTableRef, OrderedTable, OrderedTableRef, Table, TableRef
from std / options import Option
from largeints import int128, uint128, int256, uint256

type

    InvalidSequenceLength* = object of RangeDefect

    InvalidBcsStructure* = object of CatchableError

    ContainerDepthError* = object of RangeDefect

    Serializables* = CountTable | CountTableRef | OrderedTable | OrderedTableRef | Table | TableRef | int128 | uint128 | int256 | uint256 | bool | array | seq | SomeInteger | string | enum | Option

const
    MAX_CONTAINER_DEPTH* = 500 ## container depth will be the nim compilers recursion depth
    ## by default it's 10000
    MAX_SEQ_LENGHT* = high(int32)
