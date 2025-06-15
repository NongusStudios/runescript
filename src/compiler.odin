package main

import "core:fmt"
import "core:unicode/utf8"
import "core:strings"
import "core:strconv"

Precedence :: enum {
    NONE,
    ASSIGNMENT, // =
    OR, // or
    AND, // and
    EQUALITY, // == !=
    COMPARISON, // < > <= >=
    TERM, // + -
    FACTOR, // * /
    UNARY, // ! -
    CALL, // . ()
    PRIMARY,
}

Parser :: struct {
    current:  Token,
    previous: Token,
    had_error: bool,
    panic_mode: bool,
}

@(private="file")
parser: Parser

@(private="file")
current_chunk: ^Chunk

syntax_error :: proc(token: ^Token, msg: string) {
    if parser.panic_mode { return }
    parser.panic_mode = true

    fmt.eprintf("[line %d] Error", token.ln)
    if token.type == Token_Type.EOF {
        fmt.eprintf(" at end")
    } else if token.type != Token_Type.ERROR {
        fmt.eprintf(" at '%s'", token.sub)
    }

    fmt.eprintfln(": %s", msg)
    parser.had_error = true
}

@(private="file")
parser_advance :: proc() {
    parser.previous = parser.current

    for {
        parser.current = scanner_scan_token()
        if parser.current.type != Token_Type.ERROR {
            fmt.printfln("%v | %s", parser.current.type, parser.current.sub)
            break
        }

        msg := utf8.runes_to_string(parser.current.sub)
        defer delete(msg)
        syntax_error(&parser.current, msg)
    }
}

/* Checks if the current token type is equal to 'type' and advances if true, reports error if false
 * 'emsg' is reported if an error is raised
 */
@(private="file")
parser_consume :: proc(type: Token_Type, emsg: string) {
    if parser.current.type == type {
        parser_advance()
        return
    }

    syntax_error(&parser.current, emsg)
}

@(private="file")
parse_precedence :: proc(prec: Precedence) {

}

// writes an instruction to the current chunk
@(private="file")
compiler_emit_instruction :: proc(op: Op) {
    chunk_write_op(current_chunk, op, parser.previous.ln)
}

// writes an instruction with parameters to the current chunk
@(private="file")
compiler_emit_instruction_with_params :: proc(op: Op, params: []u8) {
    chunk_write_op_with_params(current_chunk, op, params, parser.previous.ln)
}

@(private="file")
compiler_emit_constant :: proc(v: Value) {
    chunk_write_constant(current_chunk, v, parser.previous.ln)
}

@(private="file")
compiler_end :: proc() {
    compiler_emit_instruction(Op.RETURN)
}

// compiles number expression
@(private="file")
compiler_number_expression :: proc() {
    sub := utf8.runes_to_string(parser.previous.sub)
    defer delete(sub)

    v: Value
    if strings.contains_rune(sub, '.') { // is float
        v = strconv.atof(sub)
    } else {
        v = i32(strconv.atoi(sub))
    }

    compiler_emit_constant(v)
}

// compiles grouping expression '(...)''
@(private="file")
compiler_grouping_expression :: proc() {
    compiler_expression()
    parser_consume(.RIGHT_PAREN, "expected ')' after expression")
}

// compiles unary '-','!' operation
@(private="file")
compiler_unary_expression :: proc() {
    op_type := parser.previous.type

    parse_precedence(.UNARY)

    #partial switch op_type {
        case .MINUS: compiler_emit_instruction(.NEGATE)
        case: return
    }
}

@(private="file")
compiler_expression :: proc() {
    parse_precedence(.ASSIGNMENT)
}

compile :: proc(src: string) -> (Chunk, bool) {
    init_scanner(src)
    defer free_scanner()

    chunk := init_chunk()
    current_chunk = &chunk

    parser_advance()
    compiler_expression()
    parser_consume(Token_Type.EOF, "expected end of expression")
    compiler_end()

    return chunk, !parser.had_error
}

// Writes chunk into a scroll file
write_scroll :: proc(chunk: ^Chunk, out: string) -> bool {
    return true
}

// Reads compiled scroll file into a chunk
read_scroll :: proc(path: string) -> (Chunk, bool) {
    return {}, true // TODO
}