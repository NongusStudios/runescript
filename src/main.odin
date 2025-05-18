package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

HELP_OUTPUT :: 
`
Usage:
    runescript cmd:arg1:arg2 ...
Commands:
  required:
    build:<path/to/src.rune>                | Compiles a runescript source file into a *.scroll file of the same name.
    run:<path/to/out.scroll>:<?'src'|'bin'> | Executes a compiled *.scroll file or builds and executes a source file,
                                              if the optional second argument is equal to 'src'.
  util:
    out:<path/of/out.scroll>                | Sets the filename and path of the outputted *.scroll file.
    timeit:<?units:'us'|'ms'|'s'>           | Displays the time taken to execute 'build' or 'run' in chosen units (seconds by default).
`

duration_in_timeit_units :: proc(units: string, d: time.Duration) -> f64 {
    switch units {
        case "s":  return time.duration_seconds(d)
        case "ms": return time.duration_milliseconds(d)
        case "us": return time.duration_microseconds(d)
    }
    return time.duration_seconds(d)
}

// builds 'output_file' from 'src_file'
build_script :: proc(path: string, out: string, timeit: bool, timeit_units: string) -> int {
    content, ok := read_file(path)
    if !ok {
        fmt.eprintfln("build_script -> error: failed to read %s", path)
        return 1
    }
    defer delete(content)

    stamp: time.Time
    if timeit { stamp = time.now() }

    chunk, result := compile(content)
    if result.e != Compile_Error.OK {
        defer delete(result.what)
        fmt.eprintfln("build_script -> error: failed to compile %s\n    what=%s", path, result.what)
        return 1
    }
    defer free_chunk(&chunk)

    write_scroll(&chunk, out)

    if timeit {
        fmt.printfln("timeit: %s compiled in %f%s", out, duration_in_timeit_units(timeit_units, time.since(stamp)), timeit_units)
    }

    return 0
}

/* executes 'path' file, which is a pre-compiled bytecode file.
 * if 'src' evaluates to true then 'path' will first be built then run
*/
run_script :: proc(path: string, src: bool, out: string, timeit: bool, timeit_units: string) -> int {
    // TODO

    return 0
}

str_from_cmd_op :: proc(op: int) -> string {
    if op == 0 {
        return "build"
    } else if op == 1 {
        return "run"
    }
    return "unknown"
}

process_args :: proc() -> int {
    if len(os.args) < 2 {
        fmt.println("info: no arguments provided, run 'help' for more info")
        return 0
    }

    operation    := -1 // 0 = build, 1 = run
    path         := ""
    out          := ""
    run_from_src := false
    timeit       := false
    timeit_units := "s"

    for cmd_arg in os.args[1:] {
        args := strings.split(cmd_arg, ":")
        switch args[0] {
            case "build":  {
                if len(args) < 2 {
                    fmt.println("build: expected file path, found none")
                    return 0
                }
                path = args[1]
                operation = 0
            }
            case "run":    {
                if len(args) < 2 {
                    fmt.println("run: expected file path, found none")
                    return 0
                }
                if len(args) > 2 {
                    if args[2] == "bin" {
                        run_from_src = false
                    } else if args[2] == "src" {
                        run_from_src = true
                    } else {
                        fmt.println("run: invalid file type, valid inputs are ['src','bin']")
                        return 0
                    }
                }
                path = args[1]
                operation = 1
            }
            case "out":    {
                if len(args) < 2 {
                    fmt.println("out: expected argument, found none")
                    return 0
                }
                out = args[1]
            }
            case "timeit": {
                timeit = true
                if len(args) > 1 {
                    timeit_units = args[1]
                    if timeit_units != "s" && timeit_units != "ms" && timeit_units != "us" {
                        fmt.printfln("timeit: invalid units %s, valid units are ['s', 'ms', 'us']", timeit_units)
                        return 0
                    }
                }
            }
            case "help":  {
                fmt.println(HELP_OUTPUT)
                return 0
            }
            case: {
                fmt.printfln("info: unknown command %s", args[0])
                return 0
            }
        }
    }

    if operation == -1 {
        fmt.println("info: no operation specified, must use either build or run command")
        return 0
    }

    if !os.is_file(path) {
        fmt.printfln("%s: %s is not a file", str_from_cmd_op(operation), path)
        return 0
    }

    if out == "" {
        s := strings.split(path, ".")
        name := strings.concatenate(s[:len(s)-1])
        out = strings.concatenate({name, ".scroll"})
    }

    if operation == 0 { // build
        build_script(path, out, timeit, timeit_units)
    } else if operation == 1 { // run
        run_script(path, run_from_src, out, timeit, timeit_units)
    } else { // just in-case
        fmt.println("info: through some form of black magic you somehow selected an operation that doesn't exist... Good job!")
    }

    return 0
}

main :: proc() {
    // init singletons
    init_vm()
    defer free_vm()

    e := process_args()
    if e != 0 {
        os.exit(e)
    }
}