package main

import "core:fmt"
import "core:os"
import "core:time"

process_args :: proc() {
    arg_count := len(os.args)
    if(arg_count < 2) {
        fmt.println("INFO: Expected runescript file as first argument");
    }

    file_path := os.args[1]
}

main :: proc(){
    init_vm()
    defer free_vm()

    test_chunk := init_chunk()
    defer free_chunk(&test_chunk)

    /* 
        return 1 + 2 * 3 - 4 / -5
        =
        LOAD 1
        LOAD 2
        LOAD 3
        MULTIPLY
        ADD
        LOAD 4
        LOAD -5
        DIVIDE
        SUBTRACT
        RETURN

        result: 7.8
    */

    chunk_write_constant(&test_chunk, f32(1.0), 1)
    chunk_write_constant(&test_chunk, f32(2.0), 1)
    chunk_write_constant(&test_chunk, f32(3.0), 1)

    chunk_write_op(&test_chunk, Op.MULTIPLY, 1)
    chunk_write_op(&test_chunk, Op.ADD, 1)

    chunk_write_constant(&test_chunk, f32(4.0), 1)
    chunk_write_constant(&test_chunk, f32(5.0), 1)
    chunk_write_op(&test_chunk, Op.NEGATE, 1)

    chunk_write_op(&test_chunk, Op.DIVIDE, 1)
    chunk_write_op(&test_chunk, Op.SUBTRACT, 1)

    /* 4 - 3 * -2 = 10 without Op.NEGATE instruction
    chunk_write_constant(&test_chunk, i32(4), 1)
    chunk_write_constant(&test_chunk, i32(3), 1)
    chunk_write_constant(&test_chunk, i32(-2), 1)

    chunk_write_op(&test_chunk, Op.MULTIPLY, 1)
    chunk_write_op(&test_chunk, Op.SUBTRACT, 1)
    */


    /* 4 - 3 * -2 = 10 without subtract
    chunk_write_constant(&test_chunk, i32(4), 1)
    chunk_write_constant(&test_chunk, i32(3), 1)
    chunk_write_op(&test_chunk, Op.NEGATE, 1)

    chunk_write_constant(&test_chunk, i32(2), 1)
    chunk_write_op(&test_chunk, Op.NEGATE, 1)

    chunk_write_op(&test_chunk, Op.MULTIPLY, 1)
    chunk_write_op(&test_chunk, Op.ADD, 1)
    */

    chunk_write_op(&test_chunk, Op.RETURN, 1)

    fmt.println("=== interpreting 'test_chunk' ===")
    start := time.now()

    vm_interpret(&test_chunk)

    duration := time.duration_microseconds(time.since(start))
    fmt.printfln("=== 'test_chunk' interpreted in %.1f us ===", duration)
}