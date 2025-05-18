package main

import "core:slice"
import "core:os"
import "core:fmt"
import "core:strings"

U8_MAX :: (1 << 8) - 1

U24_MAX :: (1 << 24) - 1
U24 :: [3]u8

u24_zero :: proc() -> U24 {
    return U24{0, 0, 0}
}

u24_from_slice :: proc(s: []u8) -> U24 {
    if(len(s) < 3) { return u24_zero() }
    return U24{s[0], s[1], s[2]}
}

u24_to_uint :: proc(v: U24) -> uint {
    u := uint(v[0])
    u = u << 8 | uint(v[1])
    u = u << 8 | uint(v[2])
    return u
}

uint_to_u24 :: proc(v: uint) -> U24 {
    u := u24_zero()
    u[0] = u8((v >> 16) & 0xff)
    u[1] = u8((v >> 8) & 0xff)
    u[2] = u8(v & 0xff)
    return u
}

// returned string is allocated and should be deleted
read_file :: proc(path: string) -> (string, bool) {
    if !os.is_file(path) {
        fmt.eprintfln("read_file() -> error: %s is not a file", path)
        return {}, false
    }

    buf, ok := os.read_entire_file(path)
    if !ok {
        fmt.eprintfln("read_file() -> error: failed to read file %s", path)
        return {}, false
    }
    defer delete(buf)

    content := strings.clone_from_bytes(buf)

    return content, true
}

// returned slice is allocated and should be deleted
read_file_as_bytes :: proc(path: string) -> ([]u8, bool) {
    if !os.is_file(path) {
        fmt.eprintfln("read_file() -> error: %s is not a file", path)
        return {}, false
    }

    buf, ok := os.read_entire_file(path)
    if !ok {
        fmt.eprintfln("read_file() -> error: failed to read file %s", path)
        return {}, false
    }

    return buf, true
}

// returned slice is allocated and should be deleted
string_to_runes :: proc(str: string) -> []rune {
    s := make([]rune, strings.rune_count(str))
    i := 0
    for ch in str {
        s[i] = ch
        i += 1
    }
    return s
}

is_digit :: proc(c: rune) -> bool {
    return c >= '0' && c <= '9'
}

is_alpha :: proc(c: rune) -> bool {
    return (c >= 'a' && c <= 'z') ||
           (c >= 'A' && c <= 'Z') ||
           c == '_'
}
