package main

import "core:strings"
import "core:fmt"
import "core:unicode/utf8"

/* NOTE: this code is a bit funky because I was trying to imitate how you might implement this in C
   It works for now but I might rewrite this to be more idiomatic with odin
*/

Token_Type :: enum {
    // single-character tokens
    LEFT_PAREN, RIGHT_PAREN,
    LEFT_BRACE, RIGHT_BRACE,
    LEFT_CURLY_BRACE, RIGHT_CURLY_BRACE,
    COMMA, DOT, END_STATEMENT,

    // operators
    EQUAL, EVAL,
    MINUS, PLUS,
    SLASH, STAR,
    NOT,   NOT_EVAL,
    GREATER_THAN, GREATER_EQUAL,
    LESS_THAN, LESS_EQUAL,

    // literals
    IDENTIFIER, STRING_LITERAL, NUMBER_LITERAL,

    // keywords
    AND, STRUCT, ELSE,
    FOR, FUNC, IF, ELIF,
    OR, RETURN, VAR,
    BREAK, CONTINUE,
    IMPORT,

    // builtin
    // ---- types
    INT, SIZE, FLOAT, DOUBLE, STRING, BOOL,
    // ---- values
    TRUE, FALSE, NIL,
    // ---- procedures
    PRINT,

    // misc
    ERROR, EOF,
    MAX
}

Token :: struct {
    type: Token_Type,
    sub:  []rune,
    ln:   uint,
}

Parser :: struct {
    src:        []rune,
    sub:        []rune,
    sub_length: uint,
    ln:  uint
}

Compile_Error :: enum {
    OK,
    ERROR,
}

Compile_Result :: struct {
    e: Compile_Error,
    what: string,
}

@(private="file")
parser: Parser

@(private="file")
init_parser :: proc(src: string) {
    init_keyword_trie()

    src           := string_to_runes(src)
    defer delete(src)
    parser.src     = make([]rune, len(src)+1)
    copy(parser.src, src)
    parser.src[len(parser.src)-1] = 0

    parser.sub        = parser.src[:]
    parser.sub_length = 1
    parser.ln         = 1
}

@(private="file")
free_parser :: proc() {
    delete(parser.src)
    parser.src = nil
    parser.sub = nil
    free_keyword_trie()
}

make_error_token :: proc(format: string, args: ..any) -> Token {
    b: strings.Builder
    strings.builder_init(&b)
    defer strings.builder_destroy(&b)

    w := fmt.sbprintf(&b, format, ..args)

    return {
        type=Token_Type.ERROR,
        sub =utf8.string_to_runes(w),
    }
}

// Same formating rules as printf
make_compile_result_error :: proc(format: string, args: ..any) -> Compile_Result {
    b: strings.Builder
    strings.builder_init(&b)
    defer strings.builder_destroy(&b)

    w := fmt.sbprintf(&b, format, ..args)

    return {Compile_Error.ERROR, w}
}

make_compile_result_ok :: proc() -> Compile_Result {
    return {e=Compile_Error.OK}
}

parser_at_end :: proc() -> bool {
    return parser.sub[parser.sub_length-1] == 0
}

parser_peek :: proc() -> rune {
    return parser.sub[parser.sub_length-1]
}

parser_peek_next :: proc() -> rune {
    if parser_at_end() { return 0 }
    return parser.sub[parser.sub_length]
}

@(private="file")
parser_advance :: proc() -> rune {
    parser.sub_length += 1
    return parser.sub[parser.sub_length-2]
}

// checks if current rune matches with c, then advances if true
@(private="file")
parser_match :: proc(c: rune) -> bool {
    if parser_at_end() { return false }
    if parser_peek() != c { return false }

    parser_advance()
    return true
}

parser_make_token :: proc(t_type: Token_Type) -> Token {
    t: Token = {
        type=t_type,
        sub =parser.sub[:parser.sub_length-1],
        ln  =parser.ln,
    }

    return t
}

// skips spaces, tabs, newlines and comments
@(private="file")
parser_skip_whitespace :: proc() {
    for {
        switch c := parser_peek(); c {
            // whitespace and newlines
            case ' ','\r','\t': {
                parser_advance()
            }
            // comments
            case '/': {
                if parser_peek_next() == '/' {
                    for parser_peek() != '\n' && !parser_at_end() { parser_advance() }
                } else if parser_peek_next() == '*' {
                    parser_advance(); parser_advance() // advance past /*
                    for !(parser_peek() == '*' && parser_peek_next() == '/') && !parser_at_end() { parser_advance() }
                    parser_advance(); parser_advance() // advance past */
                }
            }
            case: {
                return
            }
        }
    }
}

parser_check_rest_of_word :: proc(offset: uint, rest: string) -> bool {
    if parser.sub_length - offset - 1 != len(rest) { return false }
    s := utf8.runes_to_string(parser.sub[offset:parser.sub_length - 1])
    defer delete(s)

    return s == rest
}

@(private="file")
parser_make_string_token :: proc() -> Token {
    for parser_peek() != '"' && !parser_at_end() {
        if parser_peek() == '\n' { parser.ln += 1 }
        parser_advance()
    }

    if parser_at_end() { return make_error_token("unterminated string on ln: %d", parser.ln) }

    // closing quote
    parser_advance()
    return parser_make_token(Token_Type.STRING_LITERAL)
}

@(private="file")
parser_make_number_token :: proc() -> Token {
    // hehe i love indenting it makes me rock hard
    for c := parser_peek(); is_digit(c) || c == '_' || c == '.';
        c  = parser_peek()
    { parser_advance() }
    return parser_make_token(Token_Type.NUMBER_LITERAL)
}

identifier_token_type :: proc() -> Token_Type {
    if parser.sub_length == 0 { return Token_Type.ERROR }

    return keyword_trie_search(parser.sub[:parser.sub_length-1])
}

@(private="file")
parser_make_identifier_token :: proc() -> Token {
    for c := parser_peek(); is_alpha(c) || is_digit(c);
        c = parser_peek() { parser_advance() }
    return parser_make_token(identifier_token_type())
}

@(private="file")
scan_token :: proc() -> Token {
    if parser_at_end() {
        return Token{type=Token_Type.EOF}
    }

    parser_skip_whitespace()
    parser.sub = parser.sub[parser.sub_length-1:]
    parser.sub_length = 1
    
    switch c := parser_advance(); c {
        case '(': return parser_make_token(Token_Type.LEFT_PAREN)
        case ')': return parser_make_token(Token_Type.RIGHT_PAREN)
        case '[': return parser_make_token(Token_Type.LEFT_BRACE)
        case ']': return parser_make_token(Token_Type.RIGHT_BRACE)
        case '{': return parser_make_token(Token_Type.LEFT_CURLY_BRACE)
        case '}': return parser_make_token(Token_Type.RIGHT_CURLY_BRACE)
        case ',': return parser_make_token(Token_Type.COMMA)
        case '.': {
            // in-case '.1234'
            if is_digit(parser_peek()) {
                return parser_make_number_token()
            }
            return parser_make_token(Token_Type.DOT)
        }
        case '-': return parser_make_token(Token_Type.MINUS)
        case '+': return parser_make_token(Token_Type.PLUS)
        case '*': return parser_make_token(Token_Type.STAR)
        case '/': return parser_make_token(Token_Type.SLASH)
        case '!': return parser_make_token(Token_Type.NOT_EVAL      if parser_match('=') else Token_Type.NOT)
        case '=': return parser_make_token(Token_Type.EVAL          if parser_match('=') else Token_Type.EQUAL)
        case '<': return parser_make_token(Token_Type.LESS_EQUAL    if parser_match('=') else Token_Type.LESS_THAN)
        case '>': return parser_make_token(Token_Type.GREATER_EQUAL if parser_match('=') else Token_Type.GREATER_THAN)
        case '"': return parser_make_string_token()
        case ';','\n': {
            t := parser_make_token(Token_Type.END_STATEMENT)
            if c == '\n' {
                parser.ln += 1
            }
            return t
        }
        case: {
            // number literal
            if is_digit(c) { return parser_make_number_token() }
            // identifier
            if is_alpha(c) { return parser_make_identifier_token() }
        }
    }

    return make_error_token("unexpected character")
}

compile :: proc(src: string) -> (Chunk, Compile_Result) {
    init_parser(src)
    defer free_parser()

    ln: uint = 0
    for {
        token := scan_token()

        // check for errors
        if token.type == Token_Type.ERROR {
            defer delete(token.sub)
            return {}, {
                e = Compile_Error.ERROR,
                what = utf8.runes_to_string(token.sub)
            }
        }
        
        // print token line
        if token.ln != ln {
            fmt.printf("%4d ", token.ln)
            ln = token.ln
        } else { fmt.print("   | ") }
        if token.type != Token_Type.END_STATEMENT {
            fmt.printfln("%v, '%s'", token.type, token.sub)
        } else {
            fmt.printfln("%v", token.type)
        }

        if(token.type == Token_Type.EOF) { break }
    }

    return {}, make_compile_result_ok()
}

// Writes chunk into a scroll file
write_scroll :: proc(chunk: ^Chunk, out: string) -> bool {
    return true
}

// Reads compiled scroll file into a chunk
read_scroll :: proc(path: string) -> (Chunk, bool) {
    return {}, true // TODO
}