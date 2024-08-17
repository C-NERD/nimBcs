#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
type

    InvalidSequenceLength* = object of RangeDefect

    InvalidBcsStructure* = object of CatchableError

    ContainerDepthError* = object of RangeDefect

const
    MAX_CONTAINER_DEPTH* = 500 ## container depth will be the nim compilers recursion depth
 ## by default it's 10000
    MAX_SEQ_LENGHT* = high(int32)
