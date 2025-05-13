package main

import "core:slice"

/* 
 *** Chunk Implementation ***
 */
Line_Num :: struct {
    ln: uint,
    start: uint,
    end: uint,
}

// VM instructions
Op :: enum u8 {
    LOAD_CONST,
    LOAD_LONG_CONST,
    RETURN,
    MAX
}

// Represents a value of a builtin type
Value :: union{i32, u32, i64, u64, f32, f64, string /*TODO: array, map */}

// Operation chunk
Chunk :: struct {
    constants: [dynamic]Value,
    code: [dynamic]u8,
    lines: [dynamic]Line_Num
}

init_chunk :: proc() -> Chunk {
    return Chunk {
        constants = make([dynamic]Value, 0, 255),
        code = make([dynamic]u8, 0, 512),
        lines = make([dynamic]Line_Num, 0, 256)
    }
}

free_chunk :: proc(chunk: ^Chunk){
    delete(chunk.constants)
    delete(chunk.code)
    delete(chunk.lines)
}

chunk_write_line :: proc(chunk: ^Chunk, ln: uint, instruction: uint){
    last_idx := len(chunk.lines)-1
    // Check if instruction is part of last written line
    if len(chunk.lines) == 0 {
        append(&chunk.lines, Line_Num{ln, instruction, instruction})
    } else if chunk.lines[last_idx].ln == ln {
        if chunk.lines[last_idx].end < instruction {
            chunk.lines[last_idx].end = instruction
        } else if chunk.lines[last_idx].start > instruction {
            chunk.lines[last_idx].start = instruction
        }
    // if not equal to last line and greater than last line then add a new line
    } else if chunk.lines[last_idx].ln < ln {
        append(&chunk.lines, Line_Num{ln, instruction, instruction})
    }
    // do nothing if data is invalid
}

chunk_get_line :: proc(chunk: ^Chunk, instruction: uint) -> uint {
    for line in chunk.lines {
        if line.start <= instruction && line.end >= instruction {
            return line.ln
        }
    }
    return 0
}

chunk_write_op :: proc(chunk: ^Chunk, op: Op, line: uint) {
    append(&chunk.code, u8(op))
    chunk_write_line(chunk, line, len(chunk.code)-1)
}

// appends an instruction byte, and the following bytes in 'params' slice
chunk_write_op_with_params :: proc(chunk: ^Chunk, op: Op, params: []u8, line: uint){
    chunk_write_op(chunk, op, line)
    append(&chunk.code, ..params[:])
}

chunk_write_constant :: proc(chunk: ^Chunk, value: Value, line: uint) {
    location := chunk_add_constant(chunk, value)
    if location > U8_MAX {
        location_u24 := uint_to_u24(location)
        chunk_write_op_with_params(chunk, Op.LOAD_LONG_CONST, location_u24[:], line)
        return
    }
    chunk_write_op_with_params(chunk, Op.LOAD_CONST, slice.bytes_from_ptr(&location, 1), line)
}

chunk_add_constant :: proc(chunk: ^Chunk, value: Value) -> uint {
    append(&chunk.constants, value)
    return len(chunk.constants)-1
}

/*
 *** Virtual_Machine Implementation ***
*/

Virtual_Machine :: struct {
    chunk: ^Chunk,
    ip: []u8, // Instruction Pointer
}

Interpret_Result :: enum {
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR,
}

@(private="file")
vm: Virtual_Machine

init_vm :: proc() {
    vm.chunk = nil
}

free_vm :: proc() {

}

@(private="file")
vm_advance :: proc(by: uint) {
    vm.ip = vm.ip[by:]
}

// Gets the current op pointed to by vm.ip and advances it by 1
@(private="file")
vm_read_op :: proc() -> Op {
    b := vm.ip[0]
    vm_advance(1)
    return Op(b)
}

// Gets n bytes from the start of vm.ip as a slice and advances it by n. should be used for fetching code params
@(private="file")
vm_read_params :: proc(n: uint) -> []u8 {
    params := vm.ip[:n]
    vm_advance(n)
    return params
}

vm_run :: proc() -> Interpret_Result {
    for {
        #partial switch instruction := vm_read_op(); instruction {
            case Op.RETURN:
                return Interpret_Result.OK
            case Op.LOAD_CONST, Op.LOAD_LONG_CONST:
                const_index:uint = 0
                if instruction == Op.LOAD_CONST { const_index = uint(vm_read_params(1)[0]) }
                else { const_index = u24_to_uint(u24_from_slice(vm_read_params(3))) }
                // TODO
            case:
                break

        }
    }
}

vm_interpret :: proc(chunk: ^Chunk) -> Interpret_Result {
    vm.chunk = chunk
    vm.ip = chunk.code[:]

    return vm_run()
}
