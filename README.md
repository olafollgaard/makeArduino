# makeArduino
As a software developer in my daily life, I was immediately annoyed by the Arduino IDE when I started playing with Arduino in the beginning of 2017. This, in classic developer fashion, got me side-tracked, initially spending a lot more time on toolchain setup than on the actual Arduino project... Oh well :)

I decided on **Visual Studio Code** with an **old-school makefile** for building and uploading to the MCU. At work I am a Windows developer, but at home I use **Ubuntu**, and I have no plans of using this makefile on Windows, though it probably wouldn't be hard to do.

As the makefile got more complex, it led to make it re-usable via `include`, so that each individual project only needed a minimal makefile.

This makefile is the result, and I have used it for a couple of Arduino projects, some on a **Adafruit Trinket Pro 5V board**, others on **ATtiny85** chips.

## Using makeArduino.mk
The ease-of-use is based on some assumptions, some of which can be reconfigured by assigning the appropriate varables beore including makeArduino.mk.

For Atmel ATtiny8x chips, `ARDUINO_CORE_PATH` points to the [arduino-tiny](https://code.google.com/archive/p/arduino-tiny/) package, located in `~/Arduino/libraries/tiny`.

Other assumptions may be "hidden", or in plain english: It works on my setup :)

makeArduino.mk is designed to be read-only, all configuration variables can be initialized before including it.

Config variable      | Default            | Usage
-------------------- | ------------------ | ----------------------
`ARDUINO_IDE_PATH`   | `~/arduino-1.8.1/` | The Arduino IDE 1.8.1
`PROJECTS_ROOT_PATH` | `~/Arduino/`       | Personal projects
`LIBRARY_PATHS`      | `~/Arduino/my_libraries` `~/Arduino/libraries` | Home-grown and third-party libraries

There are other nitty-gritty config variables in makeArduino.mk, but these are the most important ones.

The sample `Makefile` looks like this:
```cmake
PROJECT_NAME = Sample
# TARGET_SYSTEM : uno | pro_trinket_5v | tiny_84 | tiny_85
TARGET_SYSTEM = uno
INCLUDE_LIBS =

include ../makeArduino/makeArduino.mk
```

To make a new project, copy the sample `Makefile` into your project folder and update the variables to reflect your project:

* `PROJECT_NAME` is used as name part of `.elf` and `.hex` filenames, and so must be usable as such; don't use characters like `"`, `:` or `/`.

  It can also be the filename (excl path, incl suffix) of an `.ino` sketch file, which should be placed in the same directory as your `Makefile`. However **I do not reccommend using an .ino file**, since I made some `problemMatcher`s in `.vscode/tasks.json` to get integrated error messages and locations in VSCode, and they produce confusing file names and locations for compile errors in `.ino` files.

* `TARGET_SYSTEM` specifies which hardware the project is aimed at:

  Value            | Hardware
  ---------------- | ------------------------------
  `uno`            | Plain old Arduino Uno R3 board
  `pro_trinket_5v` | Adafruit Pro Trinket 5V board
  `tiny_84`        | Atmel ATtiny84 microcontroller
  `tiny_85`        | Atmel ATtiny85 microcontroller

* `INCLUDE_LIBS` is the most advanced variable in terms of implementing makeArduino.mk, but it is very easy to use, provided that your libraries are located in one of the folders in `LIBRARY_PATHS`, and also, of course, that my "hidden assumptions" are correct :)

  It is just a list of names of the libraries you wish to include in your project.

  All `.h`, `.c`, `.cpp` and `.S` files are included by default, but you can specify per library which exact object files to include, e.g. for the Adafruit Wire library, to include only `Wire.cpp` and `utility/twi.c`:
  ```cmake
  INCLUDE_LIBS = Wire
  LIBRARY_OBJS_Wire = Wire twi
  ```
  All subfolders that contain `.h`, `.c`, `.cpp` or `.S` files are recursed into and added to the include path.

### Targets in makeArduino.mk
Target              | Purpose
------------------- | --------------------------------------------------
`all`               | Rebuild project, libs only if changed, and upload
`burnfuses`         | "Burn" fuses in ATtiny8x mcu, via Arduino ISP
`build`             | Rebuild project, libs only if changed
`fullbuild`         | Rebuild everything, both project and libraries
`mostlyclean`       | Remove project binaries, but not libraries
`realclean`/`clean` | Remove all binaries
`compile`           | Compile only what needs compiling
`nm`                | List what uses the sometimes precious space
`dumpS`             | Dump dissasembly
`upload`            | Compile if necessary, then upload to board

## Upload prerequisites
1. Make sure you can use the Arduino IDE to upload a sketch, e.g. Blink, to an Arduino board. I had to fiddle a little with the USB setup in linux before that worked, but it has worked flawlessly since
2. Proceed as follows, depending on which `TARGET_SYSTEM` you are using:

### `TARGET_SYSTEM` = `uno`
1. Plug Uno into the USB port, which should show up as /dev/ttyACM0
2. `make upload`

### `TARGET_SYSTEM` = `pro_trinket_5v`
1. Plug trinket into the USB port
2. Press reset button on the board (I have not found out how to auto-reset)
3. `make upload`

### `TARGET_SYSTEM` = `tiny_84` or `tiny_85`
1. Plug Uno into the USB port, which should show up as /dev/ttyACM0
2. From the Arduino IDE, upload the *Arduino as ISP* sketch to an Arduino Uno
3. Connect pins as follows:

   Arduino | ATtiny85 | ATtiny84
   ------- | -------- | --------
   5V      | VCC      | VCC
   GND     | GND      | GND
   Pin 13  | PB2      | PA4
   Pin 12  | PB1      | PA5
   Pin 11  | PB0      | PA6
   Pin 10  | PB5      | PB3

   ```
       ATtiny85 pins            ATtiny84 pins
          _______                  _______
    PB5 -|  \_/  |- VCC      VCC -|  \_/  |- GND
    PB3 -|       |- PB2      PB0 -|       |- PA0
    PB4 -|       |- PB1      PB1 -|       |- PA1
    GND -|_______|- PB0      PB3 -|       |- PA2
                             PB2 -|       |- PA3
                             PA7 -|       |- PA4
                             PA6 -|_______|- PA5
   ```

   (No, I did not mess up the pins :P Check the datasheets)

4. Add a 10uF capacitor between GND and RESET on the Arduino
5. `make burnfuses`
6. `make upload`

## Using `.vscode/tasks.json`
//TODO

## Using `.vscode/c_cpp_properties.json`
//TODO
