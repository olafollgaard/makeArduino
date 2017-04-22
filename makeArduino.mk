#----------------------
# Makefile for Arduino
#----------------------
# This makefile is made to be included from a simple Makefile with a simple sketch configuration,
# which only needs to define MCU and SKETCH_NAME.
#
# The configuration consists of the following variables:
#
# SKETCH_NAME : Bare sketch filename (sketch should be in the same directory as the makefile)
# MCU : Target processor (attiny84|attiny85|atmega328p)
# F_CPU : Target frequency in Hz, e.g. 8000000 or 16000000
# ARDUINO_CORE : Path to the arduino hardware core folder
# INCLUDE : Include paths
# CORE_C_FILES : List of core .c files to compile
# CORE_CPP_FILES : List of core .cpp files to compile
#
# PORT : Port for the uploader
# BOARD_TYPE : Board type for uploader
# BAUD_RATE : Comm speed for uploader
#
PORT ?= /dev/ttyACM0
BOARD_TYPE ?= arduino
BAUD_RATE ?= 115200

ifndef SKETCH_NAME
$(error !!!!! SKETCH_NAME must be defined)
endif

ifneq (,$(findstring $(MCU),attiny84 attiny85))
# Defaults for attiny84 and attiny85
F_CPU ?= 8000000
ARDUINO_CORE ?= /home/$(USER)/Arduino/libraries/tiny/avr/cores/tiny
INCLUDE ?= -I. -I$(ARDUINO_CORE)
CORE_C_FILES ?= pins_arduino WInterrupts wiring_analog wiring wiring_digital wiring_pulse wiring_shift
CORE_CPP_FILES ?= HardwareSerial main Print Tone WMath WString

else ifeq ($(MCU),atmega328p)
# Defaults for atmega328p
F_CPU ?= 16000000
ARDUINO_CORE ?= /home/$(USER)/arduino-1.8.1/hardware/arduino/avr/cores/arduino
INCLUDE ?= -I. -I$(ARDUINO_CORE)
CORE_C_FILES ?= WInterrupts wiring_analog wiring wiring_digital wiring_pulse wiring_shift
CORE_CPP_FILES ?= abi CDC HardwareSerial HardwareSerial0 HardwareSerial1 HardwareSerial2 HardwareSerial3 \
	IPAddress main new PluggableUSB Print Stream Tone USBCore WMath WString

else
$(error !!!!! This makefile does not support the selected MCU - $(MCU))
endif

#---------------------------------
# Compiler and tool configuration

CC = /usr/bin/avr-gcc
CXX = /usr/bin/avr-g++
AVR_OBJCOPY = /usr/bin/avr-objcopy 
AVRDUDE = /usr/bin/avrdude

CPPFLAGS = $(INCLUDE)
C_COMMON_FLAGS =-g -Os -w -Wall -ffunction-sections -fdata-sections -fno-exceptions \
	-mmcu=$(MCU) -DF_CPU=$(F_CPU)
CFLAGS = $(C_COMMON_FLAGS) -std=gnu99
CXXFLAGS = $(C_COMMON_FLAGS)
AVRDUDE_CONF = /etc/avrdude.conf

#-----------------------------
# Core and intermediate files

out_dir = .makeArduino
sketch_cpp = $(out_dir)/$(SKETCH_NAME).cpp
sketch_elf = $(out_dir)/$(SKETCH_NAME).elf
sketch_hex = $(out_dir)/$(SKETCH_NAME).hex
sketch_o = $(out_dir)/$(SKETCH_NAME).o
core_o = $(CORE_C_FILES:%=$(out_dir)/%.o) $(CORE_CPP_FILES:%=$(out_dir)/%.o)

#-------------------
# Targets and rules

.PHONY: all build clean compile upload

all: compile upload

build: clean compile

clean:
	$(info #### Cleanup)
	rm -rf "$(out_dir)"

compile: $(out_dir) $(sketch_hex)
	$(info #### Compile complete)

upload: compile
	$(info #### Upload to $(MCU))
	$(AVRDUDE) -q -V -p $(MCU) -C $(AVRDUDE_CONF) -c $(BOARD_TYPE) -b $(BAUD_RATE) -P $(PORT) \
	   -U flash:w:$(sketch_hex):i
	$(info #### Upload complete)

$(out_dir):
	mkdir $@

# Convert elf to hex
$(sketch_hex): $(sketch_elf)
	$(info #### Convert to $@)
	$(AVR_OBJCOPY) -O ihex -R .eeprom $< $@

# Compile to elf
$(sketch_elf): $(sketch_o) $(core_o)
	$(info #### Link to $@)
	$(CC) -mmcu=$(MCU) -lm -Wl,--gc-sections -Os -o $@ $^

# Generate sketch .cpp from .ino
$(sketch_cpp): $(SKETCH_NAME)
	$(info #### Generate $@)
	@echo '#include "WProgram.h"' > $@
	@cat $< >> $@

# Compile sketch .cpp file
$(out_dir)/%.o:: $(out_dir)/%.cpp
	$(info #### Compile $<)
	$(CXX) -c $(CXXFLAGS) $(CPPFLAGS) $< -o $@

# Compile core .c files
$(out_dir)/%.o:: $(ARDUINO_CORE)/%.c
	$(info #### Compile $<)
	$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

# Compile core .cpp files
$(out_dir)/%.o:: $(ARDUINO_CORE)/%.cpp
	$(info #### Compile $<)
	$(CXX) -c $(CXXFLAGS) $(CPPFLAGS) $< -o $@
