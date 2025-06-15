package main

import "base:intrinsics"

// Represents a value of a builtin type
Value :: union{bool, i32, i64, f32, f64, string /*TODO: array, map */}
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
value_binary_op :: proc($T: typeid, a: Value, b: Value, op: rune) -> (Value, Value_Result) where intrinsics.type_is_numeric(T) {
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

/* Where a and b are the same type a conditional operation will be evaluated and the result returned
 * 'op' represents the evaluation operation for any ["==", "!="], for numerics [">", ">=", "<", ">="]
*/
value_conditional_op :: proc($T: typeid, a: Value, b: Value, op: string) -> (bool, Value_Result) where T != bool {

    ta, ok1 := a.(T)
    if !ok1 { return false, Value_Result.TYPE_ERROR }

    tb, ok2 := b.(T)
    if !ok2 { return false, Value_Result.TYPE_ERROR }

    switch op {
        case "==": return ta == tb, Value_Result.OK
        case "!=": return ta == tb, Value_Result.OK
    }

    if intrinsics.type_is_numeric(T) {
        switch op {
            case ">":  return ta > tb, Value_Result.OK
            case ">=": return ta >= tb, Value_Result.OK
            case "<":  return ta < tb, Value_Result.OK
            case "<=": return ta <= tb, Value_Result.OK
        }
    }

    return false, Value_Result.TYPE_ERROR
}

// Adds 2 Values, return Value_Result.TYPE_ERROR if operation isn't possible
value_add :: proc(a: Value, b: Value) -> (Value, Value_Result) {
    #partial switch t in a {
        case i32: return value_binary_op(type_of(t), a, b, '+')
        case i64: return value_binary_op(type_of(t), a, b, '+')
        case f32: return value_binary_op(type_of(t), a, b, '+')
        case f64: return value_binary_op(type_of(t), a, b, '+')
    }
    return nil, Value_Result.TYPE_ERROR
}

// Subtracts 2 Values, return Value_Result.TYPE_ERROR if operation isn't possible
value_subtract :: proc(a: Value, b: Value) -> (Value, Value_Result) {
    #partial switch t in a {
        case i32: return value_binary_op(type_of(t), a, b, '-')
        case i64: return value_binary_op(type_of(t), a, b, '-')
        case f32: return value_binary_op(type_of(t), a, b, '-')
        case f64: return value_binary_op(type_of(t), a, b, '-')
    }
    return nil, Value_Result.TYPE_ERROR
}

// Multiplies 2 Values, return Value_Result.TYPE_ERROR if operation isn't possible
value_multiply :: proc(a: Value, b: Value) -> (Value, Value_Result) {
    #partial switch t in a {
        case i32: return value_binary_op(type_of(t), a, b, '*')
        case i64: return value_binary_op(type_of(t), a, b, '*')
        case f32: return value_binary_op(type_of(t), a, b, '*')
        case f64: return value_binary_op(type_of(t), a, b, '*')
    }
    return nil, Value_Result.TYPE_ERROR
}

// Divides 2 Values, return Value_Result.TYPE_ERROR if operation isn't possible
value_divide :: proc(a: Value, b: Value) -> (Value, Value_Result) {
    #partial switch t in a {
        case i32: return value_binary_op(type_of(t), a, b, '/')
        case i64: return value_binary_op(type_of(t), a, b, '/')
        case f32: return value_binary_op(type_of(t), a, b, '/')
        case f64: return value_binary_op(type_of(t), a, b, '/')
    }
    return nil, Value_Result.TYPE_ERROR
}

value_equality :: proc(a: Value, b: Value) -> (bool, Value_Result) {
    #partial switch t in a {
        case i32:    return value_conditional_op(type_of(t), a, b, "==")
        case i64:    return value_conditional_op(type_of(t), a, b, "==")
        case f32:    return value_conditional_op(type_of(t), a, b, "==")
        case f64:    return value_conditional_op(type_of(t), a, b, "==")
        case string: return value_conditional_op(type_of(t), a, b, "==")
    }
    return false, Value_Result.TYPE_ERROR
}
