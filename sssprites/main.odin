package sssprites

import "core:fmt"
import "core:log"
import "core:os"
import "core:math"
import "core:mem"
import "core:c"
import "core:path/filepath"
import "core:strings"
import "core:slice"
import "core:testing"
import stb_image "vendor:stb/image"

VERSION :: #config(VERSION, "none")

HELP :: `
Help
sssprites [directory] [-out:FILENAME]

directory   This directory is my source for image files, that I will put into a sprite sheet.
            If a directory is not provided, then the current working directory is searched for image
            files. The file names must be numbered so they are sorted correctly because that order
            will be used in the sprite sheet as well.
            Careful: Computers generally need leading zeroes in numbers if the filenames have a
            different amounts of digits!
            Don't do this:   MyFile1.png,   ..., MyFile200.png
            Instead do this: MyFile001.png, ..., MyFile200.png

-out        You can give me a filename for the output, otherwise it will just be named 'out.png' and
            be put in the current working directory.
            Supported file extensions: .png, .tga, .jpg (at 85% quality), .bmp

            Example:
            sssprites C:\my\cool\sprites -out:C:\another\path\spritesheets\sheet.png

version     Prints version number
`

IMG_EXTENSION :: enum(u8) {
    UNKNOWN, PNG, JPG, BMP, TGA,
}

IMG_EXTENSION_STR :: [?]string{
    IMG_EXT_STR_UNKNOWN,
    IMG_EXT_STR_PNG,
    IMG_EXT_STR_JPG,
    IMG_EXT_STR_JPEG,
    IMG_EXT_STR_BMP,
    IMG_EXT_STR_TGA,
}
IMG_EXT_STR_UNKNOWN :: "unknown"
IMG_EXT_STR_PNG     :: ".png"
IMG_EXT_STR_JPG     :: ".jpg"
IMG_EXT_STR_JPEG    :: ".jpeg"
IMG_EXT_STR_BMP     :: ".bmp"
IMG_EXT_STR_TGA     :: ".tga"

ALLOWED_EXTENSIONS_READ ::  [?]string{
    IMG_EXTENSION_STR[1],
    IMG_EXTENSION_STR[2],
    IMG_EXTENSION_STR[3],
    IMG_EXTENSION_STR[4],
    IMG_EXTENSION_STR[5],
}
ALLOWED_EXTENSIONS_WRITE :: [?]string{
    IMG_EXTENSION_STR[1],
    IMG_EXTENSION_STR[2],
    // no JPEG here, only JPG
    IMG_EXTENSION_STR[4],
    IMG_EXTENSION_STR[5],
}

EXT_TO_STR :: [IMG_EXTENSION]string {
    .UNKNOWN   = IMG_EXT_STR_UNKNOWN,
    .PNG       = IMG_EXT_STR_PNG,
    .JPG       = IMG_EXT_STR_JPG,
    .BMP       = IMG_EXT_STR_BMP,
    .TGA       = IMG_EXT_STR_TGA,
}

str_to_ext :: proc(str: string) -> IMG_EXTENSION {
    switch str {
        case IMG_EXTENSION_STR[1]:
            return .PNG
        case IMG_EXTENSION_STR[2], IMG_EXTENSION_STR[3]:
            return .JPG
        case IMG_EXTENSION_STR[4]:
            return .BMP
        case IMG_EXTENSION_STR[5]:
            return .TGA
        case:
            return .UNKNOWN
    }
}

Image_Meta :: struct {
    channels, x, y : c.int
}

main :: proc() {
    log_level : log.Level = .Error
    when ODIN_DEBUG {
        log_level = .Debug
        fmt.println("In gebu gmode")
    }
    context.logger = log.create_console_logger(log_level)

    output_filename := "out.png"
    dirname : string = ""
    args := os.args[1:]
    log.debug("Arguments:", args)
    for i := 0; i < len(args); i+=1 {
        a := args[i]
        switch a {
            case "-help":
                print_help()
                return
            case "version":
                fmt.println(VERSION)
                return
            case:
                if a[0] == '-' {
                    opt_full := a[1:]
                    opt_remainder := opt_full
                    opt := strings.split_iterator(&opt_remainder, ":") or_else ""
                    switch opt {
                    case "out": {
                        filename := opt_remainder
                        if filename == "" {
                            ferrorf("Error, '%v' is not a valid argument! -out needs a filename!", opt_full)
                        }
                        ext := strings.to_lower(filepath.ext(filename), context.temp_allocator)
                        if !is_output_format_supported(ext) {
                            ferrorf("Extension '%v' is not in list of supported output file formats!\nSupported formats:\n%v", ext, ALLOWED_EXTENSIONS_WRITE)
                        }
                        output_filename = filename
                        log.debug("output_filename set to", output_filename)
                    }
                    case:
                        ferrorf("Unknown parameter: '%s'", opt_full)
                    }
                } else {
                    if dirname == "" {
                        dirname = a
                        log.debug("dirname set to", dirname)
                    } else {
                        ferrorf(
    `Multiple dirnames are not supported! Can't continue, sorry.
    Maybe you meant to use a parameter and forgot the '-' at the beginning?`
                        )
                    }
                }
        }
    }

    if dirname == "" {
        fmt.println("Please provide a directory name which contains image files that you want me to put into a sprite sheet!")
        print_help()
        return
    }

    files : []os.File_Info
    {
        // glob_pattern := [?]string[dirname, "*.png"]
        // files, match_err = filepath.glob(filepath.join(glob_pattern[:]))
        handle, handle_err := os.open(dirname)
        defer os.close(handle)
        if handle_err != os.ERROR_NONE {
            ferrorf("Could not open handle to directory '%v'! Errnr: %v", dirname, handle_err)
        }
        if handle == os.INVALID_HANDLE {
            ferrorf("Got invalid handle to directory '%v'!", dirname)
        }
        files_err : os.Errno
        files, files_err = os.read_dir(handle, 0)
        if files_err != os.ERROR_NONE {
            ferrorf("Failed to read dir %v although there is a handle", dirname)
        }

    }
    if count := len(files); count < 2 {
        ferrorf("Failed! Found %v files in directory '%v', but I need at least 2!", count, dirname)
    }
    img_files := make([dynamic]string, 0, 32)
    defer delete(img_files)

    for f in files {
        if f.is_dir {
            continue
        }
        extension := strings.to_lower(filepath.ext(f.fullpath), context.temp_allocator)

        is_image_extension : bool = false
        for e in ALLOWED_EXTENSIONS_READ {
            if extension == e {
                is_image_extension = true
                break
            }
        }
        if !is_image_extension {
            log.infof("Skipping file %v because its extension is %v and not in %v", f.fullpath, extension, ALLOWED_EXTENSIONS_READ)
            continue
        }
        append(&img_files, f.fullpath)
        free_all(context.temp_allocator)
    }

    slice.sort(img_files[:])

    count := len(img_files)
    if count < 2 {
        ferrorf("Can't create a sprite sheet! Found %v image files in directory '%v' but I need at least 2 files!", count, dirname)
    }
    log.infof("Found %v images", count)
    sheet, first: Image_Meta

    // get info from first image to just guess any values that need guessing for the final sprite sheet
    ok := stb_image.info(strings.unsafe_string_to_cstring(img_files[0]), &first.x, &first.y, &first.channels) == 1
    if !ok {
        ferrorf("Failed to get image info of first image '%v'! Can't continue, because it is used to determine final sprite sheet format!", img_files[0])
    }

    nr_images_per_line, nr_images_per_column : c.int = ---, ---
    nr_images_per_line, nr_images_per_column, ok = approximate_lines_and_cols_for_roughly_square_output(first.x, first.y, c.int(count))

    // right now this is stupid, but later, I want the user to have the option to specify sheet size etc. and only guess what isn't specified yet
    if sheet.x == 0 {
        sheet.x = first.x * nr_images_per_line
    }
    if sheet.y == 0 {
        sheet.y = first.y * nr_images_per_column
    }
    if sheet.channels == 0 {
        sheet.channels = first.channels
    }
    size := int(sheet.x * sheet.y * sheet.channels)
    log.infof("Sprite sheet info: %vx%v %v channels! Size in bytes: %v", sheet.x, sheet.y, sheet.channels, size)

    sheet_data_rawptr, err_sheet_data := mem.alloc(size)
    sheet_data := cast([^]byte)sheet_data_rawptr
    if err_sheet_data != .None {
        ferrorf("Failed to allocate %v bytes for sprite sheet! Error: %v", size, err_sheet_data)
    } else {
        log.infof("Allocated %v bytes for sprite sheet!", size)
    }
    defer free(sheet_data_rawptr)

    copy_images_to_sheet_buffer(img_files[:], nr_images_per_line, sheet, sheet_data)

    write_image_to_file(output_filename, sheet, sheet_data)
}

print_help :: proc() {
    fmt.println(HELP)
}

ferrorf :: proc(str: string, args: ..any) {
    fmt.printf(str, ..args)
    os.exit(1)
}

write_image_to_file :: proc(filename: string, info: Image_Meta, data: rawptr) {
    ext_str := strings.to_lower(filepath.ext(filename), context.temp_allocator)
    if ext_str == "" {
        ext_str = IMG_EXT_STR_PNG
        log.warnf("No file extension was given! Falling back to writing the image in %v format, but the filename will stay as is: %v", ext_str, filename)
    }
    ext : IMG_EXTENSION = str_to_ext(ext_str)
    cstr_filename := strings.unsafe_string_to_cstring(filename)

    res : c.int = 0


    switch ext {
    case .PNG:
        pixel_row_stride_in_bytes : c.int = info.x * info.channels // this should be correct, see stb test: https://github.com/nothings/stb/blob/013ac3beddff3dbffafd5177e7972067cd2b5083/tests/image_test.c#L106
        res = stb_image.write_png(
            cstr_filename,
            info.x, info.y,
            info.channels,
            data,
            pixel_row_stride_in_bytes // For PNG, "stride_in_bytes" is the distance in bytes from the first byte of  a row of pixels to the first byte of the next row of pixels.
            )
    case .BMP:
        res = stb_image.write_bmp(
            cstr_filename,
            info.x, info.y,
            info.channels,
            data)
    case .JPG:
        quality := c.int(85)
        res = stb_image.write_jpg(
            cstr_filename,
            info.x, info.y,
            info.channels,
            data,
            quality)
    case .TGA:
        res = stb_image.write_tga(
            cstr_filename,
            info.x, info.y,
            info.channels,
            data)
    case .UNKNOWN:
        ferrorf(`Somehow Palpatine survived! (This is an error that should never happen)
        Your file extension '%v' on the other hand did not survive the filtering for allowed file
        types, so I won't write an image, sorry! Usually you should have gotten that info before all
        the processing was done, because now all the data is available and I'm just throwing it
        away. Probably just because of some typo. What a waste of CPU time!`, ext_str)
    }
    if res != 1 {
        ferrorf("Failed to write output file %v", filename)
    }
    fmt.printf("Successfully wrote file %v\n", filename)
}

// assume that relatively square outputs are desired
approximate_lines_and_cols_for_roughly_square_output :: proc(x, y, count: c.int) -> (nr_per_line, nr_per_col: c.int, ok: bool) {
    if x <= 0 || y <= 0 || count <= 0 {
        return
    }
    area := f32(x*y*count) // the minimum area needed for the resulting rectangle
    full_side_of_square := math.sqrt(area)

    nr_per_line_float := full_side_of_square / f32(x)
    nr_per_col_float := full_side_of_square / f32(y)
    nr_per_line = c.int(math.floor(nr_per_line_float))
    nr_per_col  = c.int(math.floor(nr_per_col_float))
    if nr_per_line * nr_per_col < count {
        rect_diff_line := math.abs(full_side_of_square - math.floor(nr_per_line_float) * f32(x))
        rect_diff_col := math.abs(full_side_of_square - math.floor(nr_per_col_float) * f32(y))
        if rect_diff_line < rect_diff_col {
            nr_per_col  = c.int(math.ceil(nr_per_col_float))
            if nr_per_line * nr_per_col < count {
                nr_per_line = c.int(math.ceil(nr_per_line_float))
            }
        } else {
            nr_per_line = c.int(math.ceil(nr_per_line_float))
            if nr_per_line * nr_per_col < count {
                nr_per_col  = c.int(math.ceil(nr_per_col_float))
            }
        }
    } else if nr_per_line * nr_per_col > count {
        // if a whole line/col is superfluous, remove that
        nr_per_line += (count / nr_per_col) - nr_per_line
        nr_per_col += (count / nr_per_line) - nr_per_col
    }
    sheet_x := nr_per_col * x
    sheet_y := nr_per_line * y
    area_diff := math.round(((f32(sheet_x * sheet_y) / area) - 1) * 100)

    log.debugf("x=%v,y=%v,count=%v : area=%v, area_diff=%v, full_side_of_square=%v,\nnr_per_line_float=%v, nr_per_col_float=%v\nnr_per_line=%v, nr_per_col=%v",
                x,  y,      count,  area,     area_diff,  full_side_of_square,    nr_per_line_float,  nr_per_col_float,
                nr_per_line, nr_per_col)

    ok = area_diff >= 0
    return
}

@(test)
test_approximate_lines_and_cols_for_roughly_square_output :: proc(t: ^testing.T) {
    expect_line_col(t=t, x=1, y=1, count=5, expected_x=3, expected_y=2)
    expect_line_col(t=t, x=3, y=3, count=4, expected_x=2, expected_y=2)
    expect_line_col(t=t, x=2, y=2, count=9, expected_x=3, expected_y=3)

    expect_line_col(t=t, x=2, y=1, count=9, expected_x=3, expected_y=3)
    expect_line_col(t=t, x=2, y=1, count=8, expected_x=3, expected_y=3)
    expect_line_col(t=t, x=2, y=1, count=7, expected_x=3, expected_y=3)
    expect_line_col(t=t, x=2, y=1, count=6, expected_x=2, expected_y=3)
    expect_line_col(t=t, x=1, y=2, count=6, expected_x=3, expected_y=2)

    expect_line_col :: proc(t: ^testing.T, x, y, count, expected_x, expected_y: c.int, loc := #caller_location) -> bool {
        nr_per_line, nr_per_col, ok := approximate_lines_and_cols_for_roughly_square_output(x, y, count)
        drawing_expected := draw_sheet(x, y, expected_x, expected_y)
        defer delete(drawing_expected)
        drawing := draw_sheet(x, y, nr_per_line, nr_per_col)
        defer delete(drawing)
        free_all(context.temp_allocator)
        return testing.expectf(t, nr_per_line == expected_x && nr_per_col == expected_y && ok == true,
                        "x=% 3v, y=% 3v, count=% 3v -> expected nr_per_line, nr_per_col = % 2v,% 2v got % 2v,% 2v and ok=%v\nExpected:\n%v\nActual:\n%v",
                        x, y, count, expected_x, expected_y, nr_per_line, nr_per_col, ok, drawing_expected, drawing,
                        loc = loc)

        draw_sheet :: proc(x, y, nr_per_line, nr_per_col: c.int, alloc := context.allocator) -> (ascii_drawing: string) {
            res_x_tmp, _ := strings.repeat("#", int(nr_per_line*x), context.temp_allocator)
            res_x, _ := strings.concatenate({res_x_tmp, "\n"}, context.temp_allocator)
            ascii_drawing, _ = strings.repeat(res_x, int(nr_per_col*y), alloc)
            return
        }
    }
}

get_next_power_of_two :: proc(num: uint) -> (power_of_two: uint) {
    // SLOW: If I get bored and am up for the challenge of putting in some assembly, then
    // try https://stackoverflow.com/a/1334289/7302392 which is using the `lzcnt` instruction
    power_of_two = 2
    for power_of_two < num {
        power_of_two *= 2
    }
    return
}

copy_images_to_sheet_buffer :: proc(img_files: []string, nr_images_per_line: c.int, sheet: Image_Meta, sheet_data: [^]byte) {
    offset_x, offset_y : c.int
    for img_path, idx in img_files {
        x, y, channels : c.int
        raw_bytes := stb_image.load(strings.unsafe_string_to_cstring(img_path), &x, &y, &channels, sheet.channels)
        if raw_bytes == nil {
            log.errorf("Failed to load image nr %v '%v'!", idx+1, img_path)
            continue
        }
        defer stb_image.image_free(raw_bytes)
        log.infof("Image '%v' loaded: %vx%v, %v channels", img_path, x, y, channels)


        assert(channels == sheet.channels)
        assert(x <= sheet.x)
        assert(y <= sheet.y)
        src_bytes_per_line := int(x*channels)
        dst_bytes_per_line := int(sheet.x*channels)
        // copy pixels line by line into sprite sheet
        for idx_line in 0..<y {
            src_offset := idx_line*c.int(src_bytes_per_line)
            src := &raw_bytes[src_offset]
            dst_offset := idx_line*c.int(dst_bytes_per_line) + offset_x + offset_y
            dst := &sheet_data[dst_offset]
            mem.copy(dst, src, src_bytes_per_line)
        }

        if (idx + 1) % int(nr_images_per_line) == 0{
            offset_y += y * c.int(dst_bytes_per_line)
            offset_x = 0
        } else {
            offset_x += x * channels
        }
    }
}

is_output_format_supported :: proc(lowercase_extension_to_test: string) -> bool {
    for e in ALLOWED_EXTENSIONS_WRITE {
        if lowercase_extension_to_test == e {
            return true
        }
    }
    return false
}