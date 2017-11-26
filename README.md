# makeArduino
As a software developer in my daily life, I was immediately annoyed by the Arduino IDE when I started playing with Arduino in the beginning of 2017. This, in classic developer fashion, got me side-tracked, initially spending a lot more time on toolchain setup than on the actual Arduino project... Oh well :)

I decided on **Visual Studio Code** with an **old-school makefile** for building and uploading to the MCU. At work I am a Windows developer, but at home I use **Ubuntu**, and I have no plans of using this makefile on Windows, though it probably wouldn't be hard to do.

As the makefile got more complex, it led to make it re-usable via `include`, so that each individual project only needed a minimal makefile.

This makefile is the result, and I have used it for a couple of different Arduino projects, some on a `Adafruit Trinket Pro 5V` board, others on `ATtiny85` chips.

## Using makeArduino.mk
The ease-of-use is based on some assumptions, some of which can be reconfigured by assigning the appropriate varables beore including makeArduino.mk.

Other assumptions may be "hidden", or in plain english: It works on my setup :)

makeArduino.mk is designed to be read-only, all configuration variables can be initialized before including it.

Config variable | Default | Usage
--- | --- | ---
`ARDUINO_IDE_PATH` | `~/arduino-1.8.1/` | The Arduino IDE 1.8.1
`PROJECTS_ROOT_PATH` | `~/Arduino/` | Personal projects
`LIBRARY_PATHS` | `~/Arduino/my_libraries` `~/Arduino/libraries` | Home-grown and third-party libraries
`ARDUINO_CORE_PATH` (for ATtiny8x) | `~/Arduino/libraries/tiny` | ATtiny8x core from [arduino-tiny](https://code.google.com/archive/p/arduino-tiny/)
`ARDUINO_CORE_PATH` (for others) | Supplied by Arduino IDE | Core for other boards

The sample `Makefile` looks like this:
```cmake
PROJECT_NAME = Sample
# TARGET_SYSTEM : uno | pro_trinket_5v | tiny_84 | tiny_85
TARGET_SYSTEM = uno
INCLUDE_LIBS =

include ../makeArduino/makeArduino.mk
```

To use in a new project, simply copy the sample `Makefile` into your project folder and update the variables to reflect your project.

### PROJECT_NAME
Project name, used as name part of .elf and .hex filenames, and so must be usable as such; don't use characters like `"`, `:` or `/`.

It can also be the filename (excl path, incl suffix) of an `.ino` sketch file, which should be placed in the same directory as `Makefile`. Initially I used .ino files, but since I made some `problemMatcher`s in `.vscode/tasks.json` to get integrated error messages and locations in VSCode, I dropped the `.ino` file because it gave confusing originating file names and line numbers.

### TARGET_SYSTEM
Value | Hardware
--- | ---
`uno` | Plain old Arduino Uno board
`pro_trinket_5v` | Adafruit Pro Trinket 5V board
`tiny_84` | Atmel ATtiny84 microcontroller
`tiny_85` | Atmel ATtiny85 microcontroller

### INCLUDE_LIBS
This variable is the most advanced one in terms of implementing makeArduino.mk, but it is very easy to use, provided that your libraries are located in one of the folders in `LIBRARY_PATHS`, and also, of course, that my "hidden assumptions" are correct :)

`INCLUDE_LIBS` should simply be a list of names of the libraries you wish to include in your project.

All `.h`, `.c`, `.cpp` and `.S` files are included by default, but you can specify per library which exact object files to include, e.g. for the Adafruit Wire library, to include only `Wire.cpp` and `utility/twi.c`:
```cmake
INCLUDE_LIBS = Wire
LIBRARY_OBJS_Wire = Wire twi
```
All subfolders that contain `.h`, `.c`, `.cpp` or `.S` files are recursed into and added to the include path.
