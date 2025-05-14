package main

import "core:slice"
import "core:fmt"
import "base:intrinsics"

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
    ADD, SUBTRACT,
    MULTIPLY, DIVIDE,
    NEGATE,
    RETURN,
    MAX
}

// Represents a value of a builtin type
Value :: union{i32, i64, f32, f64, string /*TODO: array, map */}
Value_Result :: enum {
    OK,
    TYPE_ERROR,
}

value_negate :: proc(v: Value) -> (Value, Value_Result) {    
    #partial switch t in v {
        case i32: return -t, Value_Result.OK
        case i64: return -t, Value_Result.OK
        case f32: return -t, Value_Result.OK
        case f64: return -t, Value_Result.OK
    }
    return nil, Value_Result.TYPE_ERROR
}

/* Where a and b are the same type a binary add/subtract/multiply/divide operation is executed and the result returned
 * 'op' represents what operation is to be executed and possible values are ['+','-','*','/']
 * if types are mismatched Value_Result.TYPE_ERROR is returned
*/
binary_op :: proc($T: typeid, a: Value, b: Value, op: rune) -> (Value, Value_Result) where intrinsics.type_is_numeric(T) {
        ta, ok1 := a.(T)
        if !ok1 { return nil, Value_Result.TYPE_ERROR }

        tb, ok2 := b.(T)
        if !ok2 { return nil, Value_Result.TYPE_ERROR }

        switch op {
            case '+': return ta + tb, Value_Result.OK
            case '-': return ta - tb, Value_Result.OK 
            case '*': return ta * tb, Value_Result.OK 
            case '/': return ta / tb, Value_Result.OK 
        }
        return nil, Value_Result.TYPE_ERROR
}

// Adds 2 Values, return Value_Result.TYPE_ERROR if operation isn't possible
value_add :: proc(a: Value, b: Value) -> (Value, Value_Result) {
    #partial switch t in a {
        case i32: return binary_op(type_of(t), a, b, '+')
        case i64: return binary_op(type_of(t), a, b, '+')
        case f32: return binary_op(type_of(t), a, b, '+')
        case f64: return binary_op(type_of(t), a, b, '+')
    }
    return nil, Value_Result.TYPE_ERROR
}

// Subtracts 2 Values, return Value_Result.TYPE_ERROR if operation isn't possible
value_subtract :: proc(a: Value, b: Value) -> (Value, Value_Result) {
    #partial switch t in a {
        case i32: return binary_op(type_of(t), a, b, '-')
        case i64: return binary_op(type_of(t), a, b, '-')
        case f32: return binary_op(type_of(t), a, b, '-')
        case f64: return binary_op(type_of(t), a, b, '-')
    }
    return nil, Value_Result.TYPE_ERROR
}

// Multiplies 2 Values, return Value_Result.TYPE_ERROR if operation isn't possible
value_multiply :: proc(a: Value, b: Value) -> (Value, Value_Result) {
    #partial switch t in a {
        case i32: return binary_op(type_of(t), a, b, '*')
        case i64: return binary_op(type_of(t), a, b, '*')
        case f32: return binary_op(type_of(t), a, b, '*')
        case f64: return binary_op(type_of(t), a, b, '*')
    }
    return nil, Value_Result.TYPE_ERROR
}

// Divides 2 Values, return Value_Result.TYPE_ERROR if operation isn't possible
value_divide :: proc(a: Value, b: Value) -> (Value, Value_Result) {
    #partial switch t in a {
        case i32: return binary_op(type_of(t), a, b, '/')
        case i64: return binary_op(type_of(t), a, b, '/')
        case f32: return binary_op(type_of(t), a, b, '/')
        case f64: return binary_op(type_of(t), a, b, '/')
    }
    return nil, Value_Result.TYPE_ERROR
}

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

// Initial capacity of the VMs value stack
STACK_START_CAPACITY :: 256

Virtual_Machine :: struct {
    chunk: ^Chunk,
    ip: []u8, // Instruction Pointer
    offset: uint,
    stack: [dynamic]Value,
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
    vm.stack = make([dynamic]Value, 0, STACK_START_CAPACITY)
}

free_vm :: proc() {
    delete(vm.stack)
}

@(private="file")
vm_stack_clear :: proc(){
    clear(&vm.stack)
}

@(private="file")
vm_stack_top :: proc() -> Value {
    return vm.stack[len(vm.stack)-1]
}

@(private="file")
vm_stack_set_top :: proc(v: Value) {
    vm.stack[len(vm.stack)-1] = v
}

// Pushes a value to the top of the stack
@(private="file")
vm_stack_push :: proc(v: Value){
    append(&vm.stack, v)
}

// Removes value at the top of the stack and returns it
@(private="file")
vm_stack_pop :: proc() -> Value {
    v := vm_stack_top()
    pop(&vm.stack)
    return v
}

@(private="file")
vm_advance :: proc(by: uint) {
    vm.ip = vm.ip[by:]
    vm.offset += by
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

/* Performs a binary operation on the current values on the stack
 * If value types are mismatched then a COMPILE_ERROR is returned
*/
@(private="file")
vm_binary_op :: proc(op: rune) -> Interpret_Result {
    b := vm_stack_pop()
    a := vm_stack_pop()
    c, result := Value(nil), Value_Result.OK

    switch op {
        case '+': c, result = value_add(a, b)
        case '-': c, result = value_subtract(a, b)
        case '*': c, result = value_multiply(a, b)
        case '/': c, result = value_divide(a, b)
    }

    if result != Value_Result.OK { return Interpret_Result.COMPILE_ERROR }
    vm_stack_push(c)
    return Interpret_Result.OK
}

// Displays useful debug information for the current instruction
@(private="file")
vm_trace_execution :: proc() {
    // Display stack contents
    fmt.printf("           ")
    for slot in vm.stack {
        fmt.printf("[ %v ]", slot)
    }
    fmt.print("\n")

    // Trace current instruction
    offset := vm.offset
    disassemble_byte(vm.chunk, &offset)
}

// Dispatches the vm's current chunk
@(private="file")
vm_run :: proc() -> Interpret_Result {
    for {
        when ODIN_DEBUG {
            vm_trace_execution()
        }

        #partial switch instruction := vm_read_op(); instruction {
            case Op.LOAD_CONST, Op.LOAD_LONG_CONST:
                const_index:uint = 0
                if instruction == Op.LOAD_CONST { const_index = uint(vm_read_params(1)[0]) }
                else { const_index = u24_to_uint(u24_from_slice(vm_read_params(3))) }
                vm_stack_push(vm.chunk.constants[const_index])
            case Op.NEGATE:
                negated_value, result := value_negate(vm_stack_top())
                if result != Value_Result.OK { return Interpret_Result.COMPILE_ERROR }
                vm_stack_set_top(negated_value)
            case Op.ADD:      if r := vm_binary_op('+'); r != Interpret_Result.OK { return r }
            case Op.SUBTRACT: if r := vm_binary_op('-'); r != Interpret_Result.OK { return r }
            case Op.MULTIPLY: if r := vm_binary_op('*'); r != Interpret_Result.OK { return r }
            case Op.DIVIDE:   if r := vm_binary_op('/'); r != Interpret_Result.OK { return r }
            case Op.RETURN:
                ret := vm_stack_pop()
                fmt.println(ret)
                return Interpret_Result.OK
        }
    }
}

// Executes a chunk of byte code
vm_interpret :: proc(chunk: ^Chunk) -> Interpret_Result {
    vm.chunk = chunk
    vm.ip = chunk.code[:]
    vm.offset = 0
    vm_stack_clear()

    return vm_run()
}
