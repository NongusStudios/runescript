package main

import "core:strings"
import "core:fmt"
import "core:unicode/utf8"

Token_Type :: enum {
    // single-character tokens
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACKET,
    RIGHT_BRACKET,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    COLON,
    OPTIONAL,

    // operators
    EQUAL,
    EVAL,
    MINUS,
    PLUS,
    SLASH,
    STAR,
    NOT,
    NOT_EVAL,
    GREATER_THAN,
    GREATER_EQUAL,
    LESS_THAN,
    LESS_EQUAL,

    // literals
    IDENTIFIER,
    STRING_LITERAL,
    /* NOTE: These literal types were for an experiment with string interpolation which may be reimplemented later
        STRING_LITERAL_START,
        STRING_LITERAL_END,
        STRING_LITERAL_VALUE,
        STRING_INTERP_START,
        STRING_INTERP_END,
    */
    NUMBER_LITERAL,

    // keywords
    AND,
    STRUCT,
    ELSE,
    FOR,
    FUNC,
    IF,
    ELIF,
    OR,
    RETURN,
    VAR,
    BREAK,
    CONTINUE,
    IMPORT,

    // builtin
    // ---- types
    INT,
    SIZE,
    FLOAT,
    DOUBLE,
    STRING,
    BOOL,
    // ---- values
    TRUE,
    FALSE,
    NIL,
    // ---- procedures
    PRINT,

    // misc
    END_STATEMENT,
    EOF,
    ERROR,
    MAX
}

Token :: struct {
    type: Token_Type,
    sub:  []rune,
    ln:   uint,
}

Scanner :: struct {
    src:        []rune,
    sub:        []rune,
    sub_length: uint,
    ln:  uint,
    //tokenQueue: [dynamic]Token, // For single statements that need multiple tokens generated within their context
                                  // e.g. string interpolation
}

@(private="file")
scanner: Scanner

init_scanner :: proc(src: string) {
    init_keyword_trie()

    src           := string_to_runes(src)
    defer delete(src)
    scanner.src     = make([]rune, len(src)+1)
    copy(scanner.src, src)
    scanner.src[len(scanner.src)-1] = 0

    scanner.sub        = scanner.src[:]
    scanner.sub_length = 1
    scanner.ln         = 1

    //scanner.tokenQueue = make([dynamic]Token, 0, 32)
}

free_scanner :: proc() {
    delete(scanner.src)
    scanner.src = nil
    scanner.sub = nil

    //delete(scanner.tokenQueue)
    //scanner.tokenQueue = nil
    
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

scanner_at_end :: proc() -> bool {
    return scanner.sub[scanner.sub_length-1] == 0
}

scanner_peek :: proc() -> rune {
    return scanner.sub[scanner.sub_length-1]
}

scanner_peek_next :: proc() -> rune {
    if scanner_at_end() { return 0 }
    return scanner.sub[scanner.sub_length]
}

@(private="file")
scanner_advance :: proc() -> rune {
    scanner.sub_length += 1
    return scanner.sub[scanner.sub_length-2]
}

@(private="file")
scanner_reset_substring :: proc() {
    scanner.sub = scanner.sub[scanner.sub_length-1:]
    scanner.sub_length = 1
}

// checks if current rune matches with c, then advances if true
@(private="file")
scanner_match :: proc(c: rune) -> bool {
    if scanner_at_end() { return false }
    if scanner_peek() != c { return false }

    scanner_advance()
    return true
}

scanner_make_token :: proc(t_type: Token_Type) -> Token {
    t: Token = {
        type=t_type,
        sub =scanner.sub[:scanner.sub_length-1],
        ln  =scanner.ln,
    }

    return t
}

// skips spaces, tabs, newlines and comments
@(private="file")
scanner_skip_whitespace :: proc() {
    for {
        switch c := scanner_peek(); c {
            // whitespace and newlines
            case ' ','\r','\t': {
                scanner_advance()
            }
            // comments
            case '/': {
                if scanner_peek_next() == '/' {
                    for scanner_peek() != '\n' && !scanner_at_end() { scanner_advance() }
                    scanner_advance() // advance past newline
                    scanner.ln += 1
                } else if scanner_peek_next() == '*' {
                    scanner_advance(); scanner_advance() // advance past /*
                    for !(scanner_peek() == '*' && scanner_peek_next() == '/') && !scanner_at_end() {
                        if scanner_peek() == '\n' {
                            scanner.ln += 1
                        }           
                        scanner_advance()
                    }
                    scanner_advance(); scanner_advance() // advance past */
                } else { return }
            }
            case: {
                return
            }
        }
    }
}

/*scanner_check_rest_of_word :: proc(offset: uint, rest: string) -> bool {
    if scanner.sub_length - offset - 1 != len(rest) { return false }
    s := utf8.runes_to_string(scanner.sub[offset:scanner.sub_length - 1])
    defer delete(s)

    return s == rest
}*/

@(private="file")
scanner_make_string_token :: proc() -> Token {
/* NOTE:  This definition of make_string_token was for when I was playing around with how I might emit tokens for string interpolation.
    t := scanner_make_token(Token_Type.STRING_LITERAL_START)
    scanner_reset_substring()

    tokens := make([dynamic]Token, 0, 32)
    defer delete(tokens)

    for scanner_peek() != '"' && !scanner_at_end() {
        switch scanner_peek() {
            case '\n': {
                scanner.ln += 1
                scanner_advance()
            }
            case '\\': if scanner_peek_next() == '$' { scanner_advance(); scanner_advance() }
            case '$': if scanner_peek_next() == '{' {
                if scanner.sub_length > 1 {
                    append(&tokens, scanner_make_token(Token_Type.STRING_LITERAL_VALUE))
                    scanner_reset_substring()
                }

                scanner_advance(); scanner_advance()
                append(&tokens, scanner_make_token(Token_Type.STRING_INTERP_START))
                scanner_reset_substring()

                for scanner_peek() != '}' && !scanner_at_end() {
                    append(&tokens, scanner_scan_token())
                    // take tokens out of queue from nested string and put them into the right sequence
                    for len(scanner.tokenQueue) > 0 {
                        append(&tokens, scanner.tokenQueue[0])
                        ordered_remove(&scanner.tokenQueue, 0)
                    }
                }
                if scanner_at_end() { return make_error_token("unterminated interpolation in string on ln: %d", scanner.ln) }

                scanner_reset_substring(); scanner_advance() // past closing }

                append(&tokens, scanner_make_token(Token_Type.STRING_INTERP_END))
                scanner_reset_substring()
            }
            case: scanner_advance()
        }
    }

    if scanner_at_end() { return make_error_token("unterminated string on ln: %d", scanner.ln) }

    if scanner.sub_length > 1 {
        append(&tokens, scanner_make_token(Token_Type.STRING_LITERAL_VALUE))
        scanner_reset_substring()
    }

    scanner_advance()
    append(&tokens, scanner_make_token(Token_Type.STRING_LITERAL_END))
    scanner_reset_substring()

    append(&scanner.tokenQueue, ..tokens[:])

    return t
*/

    for scanner_peek() != '"' && !scanner_at_end() {
        if scanner_peek() == '\n' { scanner.ln += 1 }
        scanner_advance()
    }

    if scanner_at_end() { return make_error_token("unterminated string on ln: %d", scanner.ln) }

    // closing quote
    scanner_advance()
    return scanner_make_token(Token_Type.STRING_LITERAL)
}

@(private="file")
scanner_make_number_token :: proc() -> Token {
    for c := scanner_peek(); is_digit(c) || c == '_' || c == '.';
        c  = scanner_peek()
    { scanner_advance() }
    return scanner_make_token(Token_Type.NUMBER_LITERAL)
}

identifier_token_type :: proc() -> Token_Type {
    if scanner.sub_length == 0 { return Token_Type.ERROR }

    return keyword_trie_search(scanner.sub[:scanner.sub_length-1])
}

@(private="file")
scanner_make_identifier_token :: proc() -> Token {
    for c := scanner_peek(); is_alpha(c) || is_digit(c);
        c = scanner_peek() { scanner_advance() }
    return scanner_make_token(identifier_token_type())
}

scanner_scan_token :: proc() -> Token {
/*
    // return first token from queue and remove it, if queue contains anything
    if len(scanner.tokenQueue) > 0 {
        t := scanner.tokenQueue[0]
        ordered_remove(&scanner.tokenQueue, 0)
        return t
    }
*/

    if scanner_at_end() {
        return Token{type=Token_Type.EOF}
    }

    scanner_skip_whitespace()
    scanner_reset_substring()
    
    switch c := scanner_advance(); c {
        case '(': return scanner_make_token(Token_Type.LEFT_PAREN)
        case ')': return scanner_make_token(Token_Type.RIGHT_PAREN)
        case '[': return scanner_make_token(Token_Type.LEFT_BRACKET)
        case ']': return scanner_make_token(Token_Type.RIGHT_BRACKET)
        case '{': return scanner_make_token(Token_Type.LEFT_BRACE)
        case '}': return scanner_make_token(Token_Type.RIGHT_BRACE)
        case ',': return scanner_make_token(Token_Type.COMMA)
        case '.': {
            // in-case '.1234'
            if is_digit(scanner_peek()) {
                return scanner_make_number_token()
            }
            return scanner_make_token(Token_Type.DOT)
        }
        case '-': return scanner_make_token(Token_Type.MINUS)
        case '+': return scanner_make_token(Token_Type.PLUS)
        case '*': return scanner_make_token(Token_Type.STAR)
        case '/': return scanner_make_token(Token_Type.SLASH)
        case '?': return scanner_make_token(Token_Type.OPTIONAL)
        case ':': return scanner_make_token(Token_Type.COLON)
        case '!': return scanner_make_token(Token_Type.NOT_EVAL      if scanner_match('=') else Token_Type.NOT)
        case '=': return scanner_make_token(Token_Type.EVAL          if scanner_match('=') else Token_Type.EQUAL)
        case '<': return scanner_make_token(Token_Type.LESS_EQUAL    if scanner_match('=') else Token_Type.LESS_THAN)
        case '>': return scanner_make_token(Token_Type.GREATER_EQUAL if scanner_match('=') else Token_Type.GREATER_THAN)
        case '"': return scanner_make_string_token()
        case ';','\n': {
            t := scanner_make_token(Token_Type.END_STATEMENT)
            if c == '\n' {
                scanner.ln += 1
            }
            return t
        }
        case: {
            // number literal
            if is_digit(c) { return scanner_make_number_token() }
            // identifier
            if is_alpha(c) { return scanner_make_identifier_token() }
        }
    }

    return make_error_token("unexpected character '%c' at line %d", scanner.sub[scanner.sub_length-2], scanner.ln)
}