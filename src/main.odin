package sssprites

import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "vendor:sdl2"
import sdl_image "vendor:sdl2/image"

HELP :: `
Help
sssprites [directory]

directory   This directory is my source for image files, that I will put into a sprite sheet.
            If a directory is not provided, then the current working directory is searched for image
            files.
`

main :: proc() {
    log_level : log.Level = .Warning
    when ODIN_DEBUG {
        log_level = .Debug
    }
    context.logger = log.create_console_logger(log_level)

    dirname : string = ""
    args := os.args[1:]
    log.debug("Arguments:", args)
    for i := 0; i < len(args); i+=1 {
        a := args[i]
        switch a {
            case "-help":
                print_help()
                return
            case:
                if a[0] == '-' {
                    ferrorf("Unknown parameter: '%s'", a)
                }
                if dirname == "" {
                    dirname = a
                } else {
                    ferrorf(
`Multiple dirnames are not supported! Can't continue, sorry.
Maybe you meant to use a parameter and forgot the '-' at the beginning?`
                    )
                }
        }
    }

    if dirname == "" {
        fmt.println("Please provide a directory name which contains image files that you want me to put into a sprite sheet!")
        print_help()
        return
    }

    handle, handle_err := os.open(dirname)
    if handle_err != os.ERROR_NONE {
        ferrorf("Could not open handle to directory '%v'! Errnr: %v", dirname, handle_err)
    }
    if handle == os.INVALID_HANDLE {
        ferrorf("Got invalid handle to directory '%v'!", dirname)
    }
    files, files_err := os.read_dir(handle, 0)
    if files_err != os.ERROR_NONE {
        ferrorf("Failed to read dir %v although there is a handle", dirname)
    }
    if count := len(files); count < 2 {
        ferrorf("Failed! Found %v files in directory '%v', but I need at least 2!", count, dirname)
    }
    img_files := make([dynamic]os.File_Info, 0, 32)
    for f in files {
        if f.is_dir {
            continue
        }
        extension := filepath.ext(f.fullpath)
        if extension != ".png" {
            log.info("Skipping file %v because its extension is %v, not png", f.fullpath, extension)
            continue
        }
        append(&img_files, f)
    }

    count := len(img_files)
    if count < 2 {
        ferrorf("Can't create a sprite sheet! Found %v image files in directory %v but I need at least 2 files!", count, dirname)
    }

    flags := sdl2.InitFlags{.VIDEO}
    err_code := sdl2.Init(flags)
    if err_code != 0 {
        ferrorf("Failed to init SDL!")
        return
    }
    log.debug("SDL2 init of subsystems video successful")
    sdl_image.Init({.PNG})

    surfaces := make([dynamic]^sdl2.Surface, 0, count)
    for img in img_files {
        surface := sdl_image.Load(strings.unsafe_string_to_cstring(img.fullpath))
        if surface == nil {
            ferrorf("SDL could not load image '%v'! Is the file broken or is the extension wrong?", img.fullpath)
        }
        append(&surfaces, surface)
    }

    for surf in surfaces {
        fmt.print(surf)
    }
}

print_help :: proc() {
    fmt.println(HELP)
}

ferrorf :: proc(str: string, args: ..any) {
    fmt.printf(str, ..args)
    os.exit(1)
}