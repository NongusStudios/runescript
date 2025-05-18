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
    COMMA, DOT, SEMICOLON,

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
    src: []rune,
    sub: []rune,
    start: uint,
    current: uint,
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
    src           := string_to_runes(src)
    defer delete(src)
    parser.src     = make([]rune, len(src)+1)
    copy(parser.src, src)
    parser.src[len(parser.src)-1] = 0

    parser.sub     = parser.src[0:1]
    parser.start   = 0
    parser.current = 0
    parser.ln      = 1
}

@(private="file")
free_parser :: proc() {
    delete(parser.src)
    parser.src = nil
    parser.sub = nil
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
    return parser.src[parser.current] == 0
}

parser_peek :: proc() -> rune {
    return parser.sub[len(parser.sub)-1]
}

parser_peek_next :: proc() -> rune {
    if parser_at_end() { return 0 }
    return parser.src[parser.current+1]
}

@(private="file")
parser_advance :: proc() -> rune {
    parser.current += 1
    parser.sub = parser.src[parser.start:parser.current+1]
    return parser.sub[len(parser.sub)-2]
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
        sub =parser.sub[:parser.current-parser.start],
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
            case '\n': {
                parser.ln += 1
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
            case: return
        }
    }
}

parser_check_rest_of_word :: proc(offset: int, rest: string) -> bool {
    if len(parser.sub[offset:parser.current-parser.start]) != len(rest) { return false }
    s := utf8.runes_to_string(parser.sub[offset:parser.current-parser.start])
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

// TODO create a less hard-coded way of checking keywords while still preserving performance
identifier_token_type :: proc() -> Token_Type {
    sub_len := len(parser.sub)
    if sub_len == 0 { return Token_Type.ERROR }

    switch parser.sub[0] {
        case 'a': if parser_check_rest_of_word(1, "nd") {
            return Token_Type.AND
        }
        case 'b': if sub_len > 1 { switch parser.sub[1] {
            case 'r': if parser_check_rest_of_word(2, "eak") {
                return Token_Type.BREAK
            }
            case 'o': if parser_check_rest_of_word(2, "ol") {
                return Token_Type.BOOL
            }
        }}
        case 'c': if parser_check_rest_of_word(1, "ontinue") {
            return Token_Type.CONTINUE
        }
        case 'd': if parser_check_rest_of_word(1, "double") {
            return Token_Type.DOUBLE
        }
        case 'e': if sub_len == 4 && parser.sub[1] == 'l' {
            switch parser.sub[2] {
                case 'i': if parser.sub[3] == 'f' { return Token_Type.ELIF }
                case 's': if parser.sub[3] == 'e' { return Token_Type.ELSE }
            }
        }
        case 'f': if sub_len > 1 { switch parser.sub[1] {
            case 'a': if parser_check_rest_of_word(2, "lse") {
                return Token_Type.FALSE
            }
            case 'l': if parser_check_rest_of_word(2, "oat") {
                return Token_Type.FLOAT
            }
            case 'u': if parser_check_rest_of_word(2, "nc") {
                return Token_Type.FUNC
            }
        }}
        case 'i': if sub_len > 1 { switch parser.sub[1] {
            case 'f': return Token_Type.IF
            case 'm': if parser_check_rest_of_word(2, "port") {
                return Token_Type.IMPORT
            }
            case 'n': if sub_len == 3 && parser.sub[2] == 't' {
                return Token_Type.INT
            }
        }}
        case 'o': if sub_len == 2 && parser.sub[1] == 'r' {
            return Token_Type.OR
        }
        case 'p': if parser_check_rest_of_word(1, "rint") {
            return Token_Type.PRINT
        }
        case 's': if sub_len > 1 { switch parser.sub[1] {
            case 'i': if parser_check_rest_of_word(2, "ze") {
                return Token_Type.SIZE
            }            // length of string and struct is 6 
            case 't': if sub_len == 6 && parser.sub[2] == 'r'{
                switch parser.sub[3] {
                    case 'i': if parser_check_rest_of_word(4, "ng") {
                        return Token_Type.STRING
                    }
                    case 'u': if parser_check_rest_of_word(4, "ct") {
                        return Token_Type.STRUCT
                    }
                }
            }
        }}
        case 'v': if parser_check_rest_of_word(1, "ar"){
            return Token_Type.VAR
        }
        case 't': if parser_check_rest_of_word(1, "rue"){
            return Token_Type.TRUE
        }
    }
    return Token_Type.IDENTIFIER
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
    parser.start = parser.current
    parser.sub = parser.src[parser.start:parser.current+1]
    
    switch c := parser_advance(); c {
        case '(': return parser_make_token(Token_Type.LEFT_PAREN)
        case ')': return parser_make_token(Token_Type.RIGHT_PAREN)
        case '[': return parser_make_token(Token_Type.LEFT_BRACE)
        case ']': return parser_make_token(Token_Type.RIGHT_BRACE)
        case '{': return parser_make_token(Token_Type.LEFT_CURLY_BRACE)
        case '}': return parser_make_token(Token_Type.RIGHT_CURLY_BRACE)
        case ';': return parser_make_token(Token_Type.SEMICOLON)
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
        fmt.printfln("%v, '%s'", token.type, token.sub)

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