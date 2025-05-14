package main

import "core:fmt"

// Debug function for printing a chunks instructions
disassemble_byte :: proc(chunk: ^Chunk, offset: ^uint) {
    fmt.printf("%05d ", offset^)
    ln := chunk_get_line(chunk, offset^);
    if offset^ > 0 && ln == chunk_get_line(chunk, offset^ - 1) {
        fmt.print("   | ")
    } else {
        fmt.printf("%4d ", ln)
    }

    op := chunk.code[offset^]
    #partial switch o := Op(op); o {
        case Op.LOAD_CONST, Op.LOAD_LONG_CONST:
            fmt.printf("%s ", o)
            offset^ += 1

            const: uint
            if o == Op.LOAD_CONST {
                const = uint(chunk.code[offset^])
                offset^ += 1
            } else {
                const = u24_to_uint(
                            u24_from_slice(chunk.code[offset^ : offset^ + 3])
                )
                offset^ += 3
            }
            
            fmt.printfln("%d '%v'", const, chunk.constants[const])

        case: // Print any operands with no params or invalid operands
            if op > u8(Op.MAX) {
                fmt.eprintln("ERR: unknown bytecode")
                offset^ += 1     
                break
            }
            fmt.println(o)
            offset^ += 1
    }
}

disassemble_chunk :: proc(chunk: ^Chunk, name: string) {
    fmt.printfln("--- %s ---", name)
    for offset: uint = 0; offset < len(chunk.code); {
        disassemble_byte(chunk, &offset)
    }
}