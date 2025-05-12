package main

import "core:slice"

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
