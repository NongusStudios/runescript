package main

import "core:fmt"
import "core:os"
import "core:slice"

process_args :: proc() {
    arg_count := len(os.args)
    if(arg_count < 2) {
        fmt.println("INFO: Expected runescript file as first argument");
    }

    file_path := os.args[1]
}

main :: proc(){
    test_chunk := init_chunk()
    defer free_chunk(&test_chunk)

    chunk_write_constant(&test_chunk, i32(18), 1)
    chunk_write_op(&test_chunk, Op.RETURN,     1)

    disassemble_chunk(&test_chunk, "test_chunk")

    free_chunk(&test_chunk)
}