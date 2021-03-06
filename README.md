# makeArduino
An old-school makefile for Arduino/ATtiny84/85/ATmega328p projects.

## Introduction and History
As a software developer in my daily life, I was immediately annoyed by the Arduino IDE when I started playing with Arduino in the beginning of 2017. This, in classic developer fashion, got me side-tracked, initially spending a lot more time on toolchain setup than on the actual Arduino project... Oh well, imho it was time well spent ~~in the name of flexibility~~ having nerd-fun :-)

I decided on **Visual Studio Code** with an old-school makefile for building and uploading to the MCU. At work I am a Windows developer, but at home I use Ubuntu, and I have no plans of using this makefile on Windows, though it probably wouldn't be hard to do.

As the makefile got more complex, it led to make it re-usable via `include`, so that each individual project only needed a minimal makefile. Consequently, it must be project-agnostic. Most configuration variables can be initialized with project-specific content before the `include` statement.

This makefile is the result, and I have used it for a couple of Arduino projects, some on **Adafruit Pro Trinket 5V** boards, others on **ATtiny85/84** chips.

This project is licensed under the terms of the MIT license.

## Assumptions
The ease-of-use is based on some assumptions, some of which can be reconfigured by assigning the appropriate varables beore including `makeArduino.mk`.

For `tiny_84` | `tiny_85` targets, `ARDUINO_CORE_PATH` points to the [arduino-tiny](https://code.google.com/archive/p/arduino-tiny/) package, located in `~/Arduino/tiny`.

For `raw84` | `raw85` | `raw328p` targets, `ARDUINO_CORE_PATH` points to the [rawcore](https://github.com/olafollgaard/rawcore/) package, located in `~/Arduino/rawcore`.

Config variable      | Default            | Usage
-------------------- | ------------------ | ----------------------
`ARDUINO_IDE_PATH`   | `~/arduino-1.8.1/` | The Arduino IDE 1.8.1
`PROJECTS_ROOT_PATH` | `~/Arduino/`       | Personal projects
`LIBRARY_PATHS`      | `~/Arduino/my_libraries` `~/Arduino/libraries` | Home-grown and third-party libraries

There are other nitty-gritty config variables in `makeArduino.mk`, but these are the most important ones.

Other assumptions may be "hidden", or in plain english: It works on my setup :)

## Making a new project
1. Copy the sample `Makefile` into your project folder and update it to reflect your project, as detailed in the next section
2. Put your code files beside it in the project folder
   * All `.c`, `.cpp` and `.S` files in your project folder are compiled
   * Subfolders that contain `.h`, `.c`, `.cpp` or `.S` files are recursed into, added to the include path, and any `.c`, `.cpp` and `.S` files are compiled

## Typical Makefile contents
The sample `Makefile` looks like this:

```cmake
# TARGET_SYSTEM : uno | pro_trinket_5v | tiny_84 | tiny_85 | raw84 | raw85 | raw328p
TARGET_SYSTEM = uno
INCLUDE_LIBS =
PROJECT_DEFINES =

include ../makeArduino/makeArduino.mk
```

* `TARGET_SYSTEM` specifies which hardware the project is aimed at:

  Value            | Hardware
  ---------------- | ---------------------------------
  `uno`            | Plain old Arduino Uno R3 board
  `pro_trinket_5v` | Adafruit Pro Trinket 5V board
  `tiny_84`        | Atmel ATtiny84, using `tiny` core
  `tiny_85`        | Atmel ATtiny85, using `tiny` core
  `raw84`          | Atmel ATtiny84, using `rawcore`
  `raw85`          | Atmel ATtiny85, using `rawcore`
  `raw328p`        | Atmel ATmega328p, using `rawcore`

* `INCLUDE_LIBS` is the most advanced variable in terms of implementing `makeArduino.mk`, but it is very easy to use, provided that your library folders are located in one of the folders in `LIBRARY_PATHS`, and also, of course, that my "hidden assumptions" are correct :)

  It is just a space-separated list of names of the libraries you wish to include in your project.

  All `.c`, `.cpp` and `.S` files in the library folder are included by default, but you can specify per library which exact object files to include, e.g. for the Adafruit Wire library, to include only `Wire.cpp` and `utility/twi.c`:

  ```cmake
  INCLUDE_LIBS = Wire
  LIBRARY_OBJS_Wire = Wire twi
  ```

  All subfolders that contain `.h`, `.c`, `.cpp` or `.S` files are recursed into and added to the include path.

* `PROJECT_DEFINES`: Here you can put whatever global defines you want to have in your project. The defines are of course added to the compiler options, but they are also included in `.mkout/c_cpp_properties.json`, which can be copied into `.vscode/` (manually or via `make updatevscodecpp`) to let VSCode IntelliSense know how to resolve symbols.

  I use [SoftI2CMaster.h](https://github.com/felias-fogg/SoftI2CMaster) on ATtinyXX projects, and need to add something like this:

  ```
  PROJECT_DEFINES = SDA_PORT=PORTA SDA_PIN=PA6 SCL_PORT=PORTA SCL_PIN=PA4
  ```

## Targets in `makeArduino.mk`
The typical `make` targets are `build` and `upload`, but here is a short description of all the main targets:

Target              | Purpose
------------------- | --------------------------------------------------
`all`               | Rebuild project, libs only if changed, and upload
`build`             | Rebuild project, libs only if changed
`fullbuild`         | Rebuild everything, both project and libraries
`mostlyclean`       | Remove project binaries, but not libraries
`realclean`/`clean` | Remove all binaries
`buildvscodecpp`    | Generate `c_cpp_properties.json` with paths and defines, then show changes, but do not apply to `.vscode`
`updatevscodecpp`   | Generate and replace `.vscode/c_cpp_properties.json`. Manual changes in `.vscode/c_cpp_properties.json` will be lost.
`buildvscodetasks`  | Generate `tasks.json` with tasks for 'Build', 'Upload' and 'Update .vscode/c_cpp_properties.json', then show changes, but do not apply to `.vscode`
`updatevscodetasks` | Generate and replace `.vscode/tasks.json`. Manual changes in `.vscode/tasks.json` will be lost.
`buildvscode`       | Generate both `c_cpp_properties.json` and `tasks.json` and show changes, but do not apply to `.vscode`
`updatevscode`      | Generate and replace both `.vscode/c_cpp_properties.json` and `.vscode/tasks.json`. Manual changes in either will be lost.
`compile`           | Compile only changed files
`nm`                | List what uses the sometimes precious space
`dumpS`             | Dump dissasembly
`burnfuses`         | "Burn" fuses in ATtiny/ATmega mcu, via Arduino ISP
`upload`            | Compile changed files, then upload to board

When the above says "changed", only `.c`, `.cpp` or `.S` files are checked, not the `.h` files they depend on. Maybe I'll implement that later, but for now just `build`, it's not as if there is tons of flash for so much code that `build` is unreasonably slower than `compile` :)

## Upload prerequisites
1. Make sure you can use the Arduino IDE to upload a sketch, e.g. Blink, to an Arduino board. I had to fiddle a little with the USB setup in linux before that worked, but it has worked flawlessly since
2. Proceed as follows, depending on which `TARGET_SYSTEM` you are using:

### `TARGET_SYSTEM` = `uno`
1. Plug Uno into the USB port, which should show up as `/dev/ttyACM0`
2. `make upload`

### `TARGET_SYSTEM` = `pro_trinket_5v`
1. Plug trinket into the USB port
2. Press reset button on the trinket (I have not figured out how to auto-reset)
3. `make upload`

### `TARGET_SYSTEM` = `tiny_84` | `tiny_85` | `raw84` | `raw85`
1. Set up Arduino as ISP, as detailed below
2. Plug Arduino ISP into the USB port, which should show up as `/dev/ttyACM0`
3. `make burnfuses` - this only needs to be done once for each chip
4. `make upload`

#### Setting up Arduino as ISP
1. Plug Arduino into the USB port, which should show up as `/dev/ttyACM0`
2. From the Arduino IDE, upload the *Arduino as ISP* sketch
3. Unplug Arduino
4. Add a 10uF capacitor between GND and RESET on the Arduino
5. Connect the following pins to your target ATtiny8x:

   Arduino | ATtiny85 | ATtiny84
   ------- | -------- | --------
   5V      | VCC      | VCC
   GND     | GND      | GND
   Pin 13  | PB2      | PA4
   Pin 12  | PB1      | PA5
   Pin 11  | PB0      | PA6
   Pin 10  | PB5      | PB3

   ```
               ATtiny85 pins                           ATtiny84 pins
                  _______                                 _______
    10 -->  PB5 -|  \_/  |- VCC                     VCC -|  \_/  |- GND
            PB3 -|       |- PB2  <-- 13             PB0 -|       |- PA0
            PB4 -|       |- PB1  <-- 12             PB1 -|       |- PA1
            GND -|_______|- PB0  <-- 11      10 --> PB3 -|       |- PA2
                                                    PB2 -|       |- PA3
                                                    PA7 -|       |- PA4 <-- 13
                                             11 --> PA6 -|_______|- PA5 <-- 12
   ```

## Using `tasks.json` and `c_cpp_properties.json`
* `tasks.json` is the configuration that adds `Build`, `Upload` and `Update .vscode/c_cpp_properties.json` as tasks in VSCode.
* `c_cpp_properties.json` is the configuration that lets IntelliSense know how to resolve symbols via included paths and project defines.

Whenever the `compile` target is run, fresh `tasks.json` and `c_cpp_properties.json` file are generated in `.mkout`. If they is different from the ones in `.vscode`, a short `diff` is shown after `compile` is done. Make will say that an error occurred and was ignored, because `diff` returns nonzero when differences were found.

To rebuild or update `tasks.json` and `c_cpp_properties.json` without compiling the project, e.g. in a fresh new one, run one of the following:

Command | Action
--------|-------
`make buildvscode` | Generate both files
`make updatevscode` | Generate and replace both files
`make buildvscodetasks` | Generate `tasks.json`
`make updatevscodetasks` | Generate and replace `tasks.json`
`make buildvscodecpp` | Generate `c_cpp_properties.json`
`make updatevscodecpp` | Generate and replace `c_cpp_properties.json`
