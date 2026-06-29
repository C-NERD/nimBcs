#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
type

    InvalidSequenceLength* = object of RangeDefect

    InvalidBcsStructure* = object of CatchableError

const
    MAX_SEQ_LENGHT* = high(int32)
