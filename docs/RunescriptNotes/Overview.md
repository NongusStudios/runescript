A scripting language, whose interpreter will be written in Odin.
# Goals
This is a programming exercise to learn about writing languages and better familiarize myself with the Odin language + just have some plain old fun coding.

1. Create a scripting language with the following features:
	- storing, reading, and writing typed variables
	- arithmetic operands
	- for loops
	- control-flow statements (if, elif, else)
	- arrays, and maps
	- functions
	- structures
	- tuples
	- multi-file support (import)
2. (Optionally) Hook the language up to Raylib so it can be used to make simple 2d games.

# Baseline Language Details

## Entry Point
Unlike other scripting languages Runescript will have a main function as an entry point for the program, opposed to executing the first line.
```
func main() {
	// entry
}
```
## Keywords
```
and
bool
break
continue
double
elif
else
false
func
float
if
import
int
nil
or
print
size
string
struct
var
true
```
## Syntax
Runescript's syntax is inspired by a mix of both c and gdscript taking my favorite parts from each language. Runescript will not need semi-colons at the end of lines, a new line will serve as an indicator unless a bracket, or curly-brace has not been closed. Then the parser will continue reading until a closing bracket is found.
- comments: `// 1 Line Comment` `/* Multi-Line Comment */`
- semi-colon: (optional) ends the current statement
- typed variable definition: `var my_var: Type = Value`
- inferred type variable definition: `var my_var := Value`
- for-loop: `for condition {}`
- foreach-loop: `for i in j {}`
- loop control-flow: `continue`, `break`
- control-flow statements: `if condition {} elif other_condition {} else {}` | `condition1 and (condition2 or condition3)`
- logical operators: `==, !=, >, >=, <, <=, !, and, or`
- function definition: `func function_name(arg1: Type1, arg2: Type2) -> ReturnType {}`
- string literals: `"this is a string"` (can be spread over multiple lines)
- number literals: `1984 | 1_000_000 | 0.1 | .1 | 5.0 | 5.`
- tuple: `(v1, v2, v3)`
- tuple access: `tpl[0] | var (v1, v2, v3) := tpl`
	- array: `[5]int = [1, 2, 3, 4, 5]`
- map: `{str}int = {"one" = 1, "two" = 2}`
- import: `include "file.rune"`
- structures: `struct MyStruct {field1: Type1, field2: Type2}`
- return from function: `return value`
## Types
Runescript will support the expected basic types:
- `int`: 32bit integer
- `size`: 64 bit integer
- `float`: 32bit floating-point number
- `double`: 64bit floating-point number
- `string`: array of utf-8 characters
- `bool`: boolean true, false
- `[x]T`: array of `x` length of type `T`
- `{K}T`: hash map with a key type of `K` and a value type of `T`
### Nil
Variables that can equal nil will need to be explicitly marked as such in their type with a prefixed `?`.
- `var opt: ?int` will be equal to None, more explicitly `var opt: ?int = nil`
- `var opt: ?int = 1` will be equal to something
Checking if a value is `nil` will simply be checking equality in an if statement:
`if opt == nil { return nil }`

### String Interpolation
In runescript strings will support interpolation.
When `${...}` is found within a string literal whats inside the bracket will be processed as code and the output will be formatted into the string value.
## Running Runescript
Runescript files (.rune) will be compiled into bytecode files (.scroll). The compiled files can then be executed.
### Command Line Arguments
Arguments are separated by spaces, and values in those arguments are separated by colons.
Commands build and run can't be used together.
- `build:<filepath>`: builds the specified Runescript source file
- `run:<filepath>:<? 'src','bin'>`: runs a pre-compiled bytecode file outputted by build. The third argument is an optional value to determine if the provided file is in a bytecode format or source format. If `src` is chosen the file will be built and then ran. If `bin` is chosen then the compiled bytecode will be ran. If no third argument is supplied then `bin` will be chosen by default.
- `out:<name>`: sets the file name of the outputted byte code.
- `timeit:<?'us','ms','s'>`: displays time taken for the chosen commands (e.g. if present with build compile time will be shown, if present with run then script execution time will be shown), time will be shown in seconds by default
- `help`: displays commands and their valid usage.

### Example Usage
```
$ runescript build:path/to/src.rune out:path/to/out.scroll
$ runescript run:path/to/out.scroll timeit:ms
```
or
```
$ runescript run:path/to/src.rune:src out:path/to/out.scroll timeit:ms
```
## Interpreter
Runescript's interpreter will tokenize and convert all source code into bytecode before execution, and will then run through each instruction and execute it.
### Note
While this may not be the fastest method of code execution, it is the simplest, and since this project is purely for my own enjoyment, and a learning experience it will be the ideal way to implement this language.

### Bytecode
Runescript code will be compiled down to a simple list of bytes, that translate to instructions, and operands for those instructions. This bytecode is separated into chunks that would all be stored within a single VM for execution.

#### Instructions
0. `LOAD_CONST`: loads a constant from this chunks constant pool to the top of the stack
	`Params`: 
	- `uint8` representing the location of the constant in the constant pool
1. `LOAD_LONG_CONST`: Performs same action as `LOAD_CONST` but is used when `LOAD_CONST` can't represent any more locations
	`Params`:
	- `uint24` representing the location of the constant in the constant pool
2. Binary operators (`ADD, SUBTRACT, MULTIPLY, DIVIDE`): Performs binary operation on two values on top of the stack `b=top, a=next` and pushes the result back on.
3. Unary operators (`NEGATE`): Performs unary operation on the value on top of the stack and pushes it back on.
4. `RETURN`: Returns from the current path of execution to the previous one, with whatever value is on top of the stack.

#### Debug Line Encoding
When compiling a Runescript application the interpreter needs to be able to point to a specific line when an error occurs. The easiest but least efficient solution is running an array of line numbers parallel to the array of byte code, but this is inefficient because one line can contain many instructions resulting in lots of duplicated data.

Another solution would be to embed line numbers into the byte code itself, by creating a line embed instruction with a `uint24` proceeding it and then all instructions afterwards would be on that line until the next line embed instruction is encountered. While this is the most space efficient solution it pollutes Runescript's byte code with unnecessary symbols and also doesn't provide easy back-tracking from instructions to find the line its on.

The solution I will go with is similar to the first idea but instead of an `uint` per instruction, there will be `3 * uint` per line.
I will define the following struct:
```
Line_Num :: struct {
	ln: uint,
	start: uint,
	end: uint,
}
```
`ln` will be the line number.
`start` will be the index of the first instruction on that line
`end` will be the index of the last instruction on that line
These will be stored in an array in `Chunk` and `chunk_get_line(i)` will be used to get the line number of an instruction.

### The Virtual Machine (VM)
The virtual machine is the core of the interpreter, and executes the bytecode that Runescript's compile to. The VM is a singleton that is the first object initialised in the program.
It is handed a `Chunk` with `vm_interpret(...)` and then executes the bytecode within that chunk.
From there 1 of 3 results will be returned.
1. `Interpret_Result.OK`: execution finished without issue
2. `Interpret_Result.COMPILE_ERROR`: an issue within the byte code prevents execution
3. `Interpret_Result.RUNTIME_ERROR`: an error occurs while executing byte code (Nil value dereference, invalid type conversion, etc...)
#### Stack based
Runescript's virtual machine is stack based, which may not be the most efficient method of shuttling around values but it is the simplest.