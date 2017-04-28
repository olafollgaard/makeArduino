#==============================================================================
# Lightweight makefile for Arduino - olaf.ollgaard@gmail.com
#
# This makefile is made to be included from a simple Makefile with a few
# configuration parameters, where only SKETCH_NAME and TARGET_SYSTEM are
# required, e.g.:
# +------------------------
# |SKETCH_NAME = Blink.ino
# |TARGET_SYSTEM = uno
# |include makeArduino.mk
# +------------------------
# All local .cpp files are compiled as well as the sketch file
#
# Make targets: all build clean compile upload
#
# Core libraries used:
# uno, pro_trinket_5v: Libraries from Arudino IDE 1.8.1
# tiny_84, tiny_85: https://code.google.com/archive/p/arduino-tiny/

#--------------------------------------------------
# Configuration variables and their default values

# SKETCH_NAME : Bare sketch filename
# (sketch should be in the same directory as the makefile)
ifndef SKETCH_NAME
$(error !!!!! SKETCH_NAME must be defined)
endif

# TARGET_SYSTEM : uno | pro_trinket_5v | tiny_84 | tiny_85
ifndef TARGET_SYSTEM
$(error !!!!! TARGET_SYSTEM must be defined)
else ifeq (,$(findstring $(TARGET_SYSTEM),uno pro_trinket_5v tiny_84 tiny_85))
$(error !!!!! Unrecognized TARGET_SYSTEM $(TARGET_SYSTEM))
endif

# F_CPU : Target frequency in Hz, e.g. 8000000 or 16000000
ifneq (,$(findstring $(TARGET_SYSTEM),uno pro_trinket_5v))
F_CPU ?= 16000000
else
F_CPU ?= 8000000
endif

# ARDUINO_AVR : Path to "hardware/arduino/avr" folder
ARDUINO_AVR ?= /home/$(USER)/arduino-1.8.1/hardware/arduino/avr

# UPLOAD_PROGRAMMER : Programmer type for uploader
# UPLOAD_PORT_CONFIG : Port configuration for the uploader
ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
UPLOAD_PROGRAMMER = usbtiny
UPLOAD_PORT_CONFIG =
else
UPLOAD_PROGRAMMER ?= arduino
UPLOAD_PORT_CONFIG ?= -b 115200 -P /dev/ttyACM0
endif

#==============================================================================

#---------------------
# Compilers and tools

CC = /usr/bin/avr-gcc
CXX = /usr/bin/avr-g++
AVR_OBJCOPY = /usr/bin/avr-objcopy 
AVRDUDE = /usr/bin/avrdude

#---------------------------------------------
# Translate TARGET_SYSTEM into compiler flags

ifneq (,$(findstring $(TARGET_SYSTEM),uno pro_trinket_5v))
mcu = atmega328p
else ifeq ($(TARGET_SYSTEM),tiny_84)
mcu = attiny84
else ifeq ($(TARGET_SYSTEM),tiny_85)
mcu = attiny85
endif

# Arduino core files
ifneq (,$(findstring $(TARGET_SYSTEM),tiny_84 tiny_85))
arduino_core = /home/$(USER)/Arduino/tiny/avr/cores/tiny
else
arduino_core = $(ARDUINO_AVR)/cores/arduino
endif
core_c_files ?= $(wildcard $(arduino_core)/*.c)
core_cpp_files ?= $(wildcard $(arduino_core)/*.cpp)
core_asm_files ?= $(wildcard $(arduino_core)/*.S)

# Defines
defines = -mmcu=$(mcu) -DF_CPU=$(F_CPU) -DARDUINO=10801 -DARDUINO_ARCH_AVR
ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
defines += -DARDUINO_AVR_PROTRINKET5
else ifeq ($(TARGET_SYSTEM),uno)
defines += -DARDUINO_AVR_UNO
endif

# Includes
include_flags = -I. -I$(arduino_core)
ifeq ($(TARGET_SYSTEM),uno)
include_flags += -I$(ARDUINO_AVR)/variants/standard
else ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
include_flags += -I$(ARDUINO_AVR)/variants/eightanaloginputs
endif

# Flags
c_common_flags = -g -Os -w -Wall $(defines) $(include_flags) \
	-ffunction-sections -fdata-sections -flto -fno-fat-lto-objects
CFLAGS = $(c_common_flags)
CXXFLAGS = $(c_common_flags) -fno-exceptions
SFLAGS = -x assembler-with-cpp
ifneq (,$(findstring $(TARGET_SYSTEM),tiny_84 tiny_85))
CFLAGS += -std=gnu99
else
CFLAGS += -std=gnu11
CXXFLAGS += -std=gnu++11
endif
avrdude_conf = /etc/avrdude.conf

#-----------------------------
# Core and intermediate files

out_dir = .makeArduino
sketch_cpp = $(out_dir)/$(SKETCH_NAME).cpp
sketch_elf = $(out_dir)/$(SKETCH_NAME).elf
sketch_hex = $(out_dir)/$(SKETCH_NAME).hex
sketch_o = $(out_dir)/$(SKETCH_NAME).cpp.o
local_o = $(addprefix $(out_dir)/,$(addsuffix .o,$(notdir $(wildcard *.cpp))))
core_o = $(addprefix $(out_dir)/core/,$(addsuffix .o,\
	$(notdir $(core_c_files)) \
	$(notdir $(core_cpp_files)) \
	$(notdir $(core_asm_files)) \
	))

#-------------------
# Targets and rules

.PHONY: all build clean compile upload

all: compile upload

build: clean compile

clean:
	$(info #### Cleanup)
	rm -rfd "$(out_dir)"

compile: $(out_dir) $(sketch_hex)
	$(info #### Compile complete)

upload: compile
	$(info #### Upload to $(TARGET_SYSTEM))
	$(AVRDUDE) -q -p $(mcu) -C $(avrdude_conf) -c $(UPLOAD_PROGRAMMER) $(UPLOAD_PORT_CONFIG) \
	   -U flash:w:$(sketch_hex):i
	$(info #### Upload complete)

$(out_dir):
	mkdir $@
	mkdir $@/core

# Convert elf to hex
$(sketch_hex): $(sketch_elf)
	$(info #### Convert to $@)
	$(AVR_OBJCOPY) -O ihex -R .eeprom $< $@

# Link to elf
$(sketch_elf): $(sketch_o) $(local_o) $(core_o)
	$(info #### Link to $@)
	$(CC) -mmcu=$(mcu) -lm -Wl,--gc-sections -Os -o $@ $^

# Generate sketch .cpp from .ino
$(sketch_cpp): $(SKETCH_NAME)
	$(info #### Generate $@)
ifneq (,$(findstring $(TARGET_SYSTEM),tiny_84 tiny_85))
	@echo '#include "WProgram.h"'>$@
else
	@echo '#include "Arduino.h"'>$@
endif
	@cat $< >> $@

# Compile sketch .cpp file
$(out_dir)/%.cpp.o:: $(out_dir)/%.cpp
	$(info #### Compile $<)
	$(CXX) -c $(CXXFLAGS) $< -o $@

# Compile local .cpp files
$(out_dir)/%.cpp.o:: %.cpp
	$(info #### Compile $<)
	$(CXX) -c $(CXXFLAGS) $< -o $@

# Compile core .c files
$(out_dir)/core/%.c.o:: $(arduino_core)/%.c
	$(info #### Compile $<)
	$(CC) -c $(CFLAGS) $< -o $@

# Compile core .cpp files
$(out_dir)/core/%.cpp.o:: $(arduino_core)/%.cpp
	$(info #### Compile $<)
	$(CXX) -c $(CXXFLAGS) $< -o $@

# Compile core .S files
$(out_dir)/core/%.S.o:: $(arduino_core)/%.S
	$(info #### Compile $<)
	$(CC) -c $(SFLAGS) $(CFLAGS) $< -o $@
