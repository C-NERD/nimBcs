#                    NimBcs
#        (c) Copyright 2023 C-NERD
#
#      See the file "LICENSE", included in this
#    distribution, for details about the copyright.
##
proc switchByteOrder*(x : seq[byte]) : seq[byte] =
    ## switch byte order to little endian
    ## only does work on big endiann cpus
    
    result = x
    when (cpuEndian == Endianness.bigEndian):
        
        var container : seq[byte]
        for pos in countdown(len(result), 0):

            container.add result[pos]

        result = container
