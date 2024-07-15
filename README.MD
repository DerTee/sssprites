# What?

A simple sprite sheet generator for the command line on Windows and Linux.

SSSprites takes a directory of PNGs / JPGs / BMPs / TGAs and puts them into a sprite sheet. Files with other extensions are ignored. The same image formats are supported for output.

Example:
```
C:\>sssprites C:\images\hero_animation -out:C:\project\game\assets\sprites\hero_animation.png

REM use the working directory as the source for images if no directory is given
C:\images\hero_animation>sssprites -out:C:\project\game\assets\sprites\hero_animation.png
```

# Why?

Surprisingly there seem to be very few usable sprite sheet generators for the command line, so I wrote this one. I guess nowadays big engines have their own tools for this and you could also make them manually or with relatively bad plugins for image editors, but I wanted something that could be easily integrated with the build script of my game projects, so here we are.

# Limitations

## Only square images are supported as output
... and the output size and number of channels are guessed by the number of image files in the input directory and the size of the first image file

Examples:
 - 4 files, first image: 128x128px, 3ch -> output image: 256x256pixels, 3 ch
 - 9 files, first image: 128x128px, 3ch -> output image: 384x384pixels, 3 ch
 - 5 files, first image: 128x128px, 3ch -> output image: 384x384pixels, 3 ch

## No way to manually specify the order of the images

The OS must provide the images in the right order, which usually means that the files must be named for alphabetical sorting.

## All input images must be the same size, same number of channels, etc.

... otherwise an error will occur. This means either all images have an alpha channel or none of them do!

# Dependencies

 - [Odin](https://odin-lang.org)'s standard library
 - [stb_image](https://github.com/nothings/stb) which is included in Odin's vendor libraries, so this should hopefully be fairly stable through future versions of Odin

# Building

SSSprites is written in [Odin](https://odin-lang.org), so you'll have to install the compiler and it's dependencies. Make sure you have at least version dev-2024-07.

Open a terminal and go to the root of the project, then type:

```
odin build sssprites -o:speed
```

Done. Now you should have the compiled binary named "sssprites.exe" in the root of your project.

# Alternatives

## Command Line

 - https://imagemagick.org see https://imagemagick.org/Usage/montage/ specifically. Just found out now, otherwise I would not have written this one. Oh well.

I didn't find any others that aren't super old and unsuited to my very simple use case, which is why I wrote my own. If you know other good CLI alternatives, please let me know, PRs with links are welcome!

## Web Based

 - https://kuut.xyz/spritesheet/
 - https://www.finalparsec.com/tools/sprite_sheet_maker
 - https://spritesheet.org
