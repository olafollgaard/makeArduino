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
# All local .cpp files are compiled as well as the sketch file and
# the libraries specified in ARDUINO_LIBS and USER_LIBS 
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

# ARDUINO_PATH : Path to arduino folder
ARDUINO_PATH ?= /home/$(USER)/arduino-1.8.1

# ARDUINO_LIB_PATH : Path to arduino libraries folder
ARDUINO_LIB_PATH ?= $(ARDUINO_PATH)/libraries

# ARDUINO_LIBS : Arduino libraries to include
ARDUINO_LIBS ?=

# USER_LIB_PATH : Path to user libraries folder
USER_LIB_PATH ?= /home/$(USER)/Arduino/libraries

# USER_LIBS : User libraries to include
USER_LIBS ?=

# F_CPU : Target frequency in Hz, e.g. 8000000 or 16000000
ifneq (,$(findstring $(TARGET_SYSTEM),uno pro_trinket_5v))
F_CPU ?= 16000000
else
F_CPU ?= 8000000
endif

# ARDUINO_AVR : Path to "hardware/arduino/avr" folder
ARDUINO_AVR ?= $(ARDUINO_PATH)/hardware/arduino/avr

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

# Arduino core path
ifneq (,$(findstring $(TARGET_SYSTEM),tiny_84 tiny_85))
arduino_core = /home/$(USER)/Arduino/tiny/avr/cores/tiny
else
arduino_core = $(ARDUINO_AVR)/cores/arduino
endif

# Defines
defines = -mmcu=$(mcu) -DF_CPU=$(F_CPU) -DARDUINO=10801 -DARDUINO_ARCH_AVR
ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
defines += -DARDUINO_AVR_PROTRINKET5
else ifeq ($(TARGET_SYSTEM),uno)
defines += -DARDUINO_AVR_UNO
endif

# Intermediate files
out_path = .makeArduino
sketch_cpp = $(out_path)/$(SKETCH_NAME).cpp
sketch_elf = $(out_path)/$(SKETCH_NAME).elf
sketch_hex = $(out_path)/$(SKETCH_NAME).hex
sketch_o = $(out_path)/$(SKETCH_NAME).cpp.o
local_o = $(addprefix $(out_path)/,$(addsuffix .o,$(notdir $(wildcard *.cpp))))

# Core and libraries
include_flags = -I.
ifeq ($(TARGET_SYSTEM),uno)
include_flags += -I$(ARDUINO_AVR)/variants/standard
else ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
include_flags += -I$(ARDUINO_AVR)/variants/eightanaloginputs
endif

define library_template =
include_flags += -I$(2)
lib_out_paths += $$(out_path)/$(1)
libs_o += $$(addprefix $$(out_path)/$(1)/,$$(addsuffix .o,$$(notdir $$(wildcard $(2)/*.c))))
libs_o += $$(addprefix $$(out_path)/$(1)/,$$(addsuffix .o,$$(notdir $$(wildcard $(2)/*.cpp))))
libs_o += $$(addprefix $$(out_path)/$(1)/,$$(addsuffix .o,$$(notdir $$(wildcard $(2)/*.S))))
$$(out_path)/$(1):
	mkdir $$@
$$(out_path)/$(1)/%.c.o:: $(2)/%.c
	$$(info #### Compile $$<)
	$$(CC) -c $$(CFLAGS) $$< -o $$@
$$(out_path)/$(1)/%.cpp.o:: $(2)/%.cpp
	$$(info #### Compile $$<)
	$$(CXX) -c $$(CXXFLAGS) $$< -o $$@
$$(out_path)/$(1)/%.S.o:: $(2)/%.S
	$$(info #### Compile $$<)
	$$(CC) -c $$(SFLAGS) $$(CFLAGS) $$< -o $$@
endef

$(eval $(call library_template,core,$(arduino_core)))
$(foreach lib,$(ARDUINO_LIBS),$(eval $(call library_template,$(lib),$(ARDUINO_LIB_PATH)/$(lib)/src)))
$(foreach lib,$(USER_LIBS),$(eval $(call library_template,$(lib),$(USER_LIB_PATH)/$(lib))))

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

#-------------------
# Targets and rules

.PHONY: all build clean compile upload

all: compile upload

build: clean compile

clean:
	$(info #### Cleanup)
	rm -rfd "$(out_path)"

compile: $(out_path) $(lib_out_paths) $(sketch_hex)
	$(info #### Compile complete)

upload: compile
	$(info #### Upload to $(TARGET_SYSTEM))
	$(AVRDUDE) -q -p $(mcu) -C $(avrdude_conf) -c $(UPLOAD_PROGRAMMER) $(UPLOAD_PORT_CONFIG) \
	   -U flash:w:$(sketch_hex):i
	$(info #### Upload complete)

$(out_path):
	mkdir $@

# Convert elf to hex
$(sketch_hex): $(sketch_elf)
	$(info #### Convert to $@)
	$(AVR_OBJCOPY) -O ihex -R .eeprom $< $@

# Link to elf
$(sketch_elf): $(sketch_o) $(local_o) $(libs_o)
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
$(out_path)/%.cpp.o:: $(out_path)/%.cpp
	$(info #### Compile $<)
	$(CXX) -c $(CXXFLAGS) $< -o $@

# Compile local .cpp files
$(out_path)/%.cpp.o:: %.cpp
	$(info #### Compile $<)
	$(CXX) -c $(CXXFLAGS) $< -o $@
