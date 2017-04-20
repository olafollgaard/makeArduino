#----------------------
# Makefile for Arduino
#----------------------
# This makefile is made to be included from a simple Makefile with a simple sketch configuration.
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
# Only SKETCH_NAME and MCU is required, the rest have defaults as defined below.
#
PORT ?= /dev/ttyACM0
BOARD_TYPE ?= arduino
BAUD_RATE ?= 115200

ifndef SKETCH_NAME
$(error !!!!! SKETCH_NAME must be defined)
endif
ifeq ($(MCU),attiny84)

F_CPU ?= 8000000
ARDUINO_CORE ?= /home/$(USER)/Arduino/tiny/avr/cores/tiny
INCLUDE ?= -I. -I$(ARDUINO_CORE)
CORE_C_FILES ?= pins_arduino WInterrupts wiring_analog wiring wiring_digital wiring_pulse wiring_shift
CORE_CPP_FILES ?= HardwareSerial main Print Tone WMath WString

else ifeq ($(MCU),attiny85)

F_CPU ?= 8000000
ARDUINO_CORE ?= /home/$(USER)/Arduino/tiny/avr/cores/tiny
INCLUDE ?= -I. -I$(ARDUINO_CORE)
CORE_C_FILES ?= pins_arduino WInterrupts wiring_analog wiring wiring_digital wiring_pulse wiring_shift
CORE_CPP_FILES ?= HardwareSerial main Print Tone WMath WString

else ifeq ($(MCU),atmega328p)

F_CPU ?= 16000000
ARDUINO_CORE ?= /home/$(USER)/arduino-1.8.1/hardware/arduino/avr/cores/arduino
INCLUDE ?= -I. -I$(ARDUINO_CORE)
CORE_C_FILES ?= WInterrupts wiring_analog wiring wiring_digital wiring_pulse wiring_shift
CORE_CPP_FILES ?= abi CDC HardwareSerial HardwareSerial0 HardwareSerial1 HardwareSerial2 HardwareSerial3 \
		IPAddress main new PluggableUSB Print Stream Tone USBCore WMath WString

else
$(error !!!!! Unrecognized MCU $(MCU))
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

tmp_dir = /tmp/make_arduino
sketch_cpp = $(tmp_dir)/$(SKETCH_NAME).cpp
sketch_elf = $(tmp_dir)/$(SKETCH_NAME).elf
sketch_hex = $(tmp_dir)/$(SKETCH_NAME).hex
sketch_o = $(tmp_dir)/$(SKETCH_NAME).o
core_o = $(CORE_C_FILES:%=$(tmp_dir)/%.o) $(CORE_CPP_FILES:%=$(tmp_dir)/%.o)

#-------------------
# Targets and rules

.PHONY: all build clean compile reset upload

all: clean compile upload

build: clean compile

clean:
		$(info #### Cleanup)
		rm -rf "$(tmp_dir)"

compile: $(tmp_dir) $(sketch_hex)
		$(info #### Compile complete)

reset:
		$(info #### Reset)
		stty --file $(PORT) hupcl
		sleep 0.1
		stty --file $(PORT) -hupcl

upload:
		$(info #### Upload to $(MCU))
		$(AVRDUDE) -q -V -p $(MCU) -C $(AVRDUDE_CONF) -c $(BOARD_TYPE) -b $(BAUD_RATE) -P $(PORT) \
			   -U flash:w:$(sketch_hex):i
		$(info #### Upload complete)

$(tmp_dir):
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
$(tmp_dir)/%.o:: $(tmp_dir)/%.cpp
		$(info #### Compile $<)
		$(CXX) -c $(CXXFLAGS) $(CPPFLAGS) $< -o $@

# Compile core .c files
$(tmp_dir)/%.o:: $(ARDUINO_CORE)/%.c
		$(info #### Compile $<)
		$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

# Compile core .cpp files
$(tmp_dir)/%.o:: $(ARDUINO_CORE)/%.cpp
		$(info #### Compile $<)
		$(CXX) -c $(CXXFLAGS) $(CPPFLAGS) $< -o $@
