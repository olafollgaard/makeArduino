#==============================================================================
# Lightweight makefile for Arduino - olaf.ollgaard@gmail.com
#
# This makefile is made to be included from a simple Makefile with a few
# configuration parameters, where only SKETCH_NAME and TARGET_SYSTEM are
# required, e.g.:
# +------------------------
# |SKETCH_NAME = Blink.ino
# |TARGET_SYSTEM = uno
# |INCLUDE_LIBS =
# |include makeArduino.mk
# +------------------------
# All local .cpp files are compiled as well as the sketch file and
# the libraries specified in INCLUDE_LIBS
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
else ifeq (,$(filter $(TARGET_SYSTEM),uno pro_trinket_5v tiny_84 tiny_85))
$(error !!!!! Unrecognized TARGET_SYSTEM $(TARGET_SYSTEM))
endif

# INCLUDE_LIBS : Names of libraries to include
INCLUDE_LIBS ?=

# ARDUINO_PATH : Path to arduino folder
ARDUINO_PATH ?= /home/$(USER)/arduino-1.8.1
# ARDUINO_AVR_PATH : Path to "hardware/arduino/avr" folder
ARDUINO_AVR_PATH ?= $(ARDUINO_PATH)/hardware/arduino/avr
# PACKAGES_PATH : Path to packages folder
PACKAGES_PATH ?= /home/$(USER)/.arduino15
# SKETCHBOOK_PATH : Path to the user sketchbook
SKETCHBOOK_PATH ?= /home/$(USER)/Arduino
# ARDUINO_CORE_PATH: Path to arduino core
ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 tiny_85))
ARDUINO_CORE_PATH ?= $(SKETCHBOOK_PATH)/tiny/avr/cores/tiny
else
ARDUINO_CORE_PATH ?= $(ARDUINO_AVR_PATH)/cores/arduino
endif
# LIBRARY_PATHS : List of paths to libraries
LIBRARY_PATHS += $(SKETCHBOOK_PATH)/libraries
ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
LIBRARY_PATHS += $(PACKAGES_PATH)/adafruit/hardware/avr/1.4.9/libraries
endif
LIBRARY_PATHS += $(ARDUINO_AVR_PATH)/libraries $(ARDUINO_PATH)/libraries

# F_CPU : Target frequency in Hz
ifneq (,$(filter $(TARGET_SYSTEM),uno pro_trinket_5v))
F_CPU ?= 16000000
else
F_CPU ?= 8000000
endif

# UPLOAD_PROGRAMMER : Programmer type for uploader
# UPLOAD_PORT_CONFIG : Port configuration for the uploader
ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
UPLOAD_PROGRAMMER = usbtiny
UPLOAD_PORT_CONFIG =
else
UPLOAD_PROGRAMMER ?= arduino
UPLOAD_PORT_CONFIG ?= -b 115200 -P /dev/ttyACM0
endif

# End of configuration section
#==============================================================================

#---------------------
# Compilers and tools

CC = /usr/bin/avr-gcc
CXX = /usr/bin/avr-g++
AVR_OBJCOPY = /usr/bin/avr-objcopy 
AVRDUDE = /usr/bin/avrdude

#---------------------------------------------
# Translate configuration into compiler flags

ifneq (,$(filter $(TARGET_SYSTEM),uno pro_trinket_5v))
mcu = atmega328p
else ifeq ($(TARGET_SYSTEM),tiny_84)
mcu = attiny84
else ifeq ($(TARGET_SYSTEM),tiny_85)
mcu = attiny85
endif

# Defines
defines := -mmcu=$(mcu) -DF_CPU=$(F_CPU) -DARDUINO=10801 -DARDUINO_ARCH_AVR
ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
defines += -DARDUINO_AVR_PROTRINKET5
else ifeq ($(TARGET_SYSTEM),uno)
defines += -DARDUINO_AVR_UNO
endif

# Intermediate files
out_path := .mkout
sketch_cpp := $(out_path)/$(SKETCH_NAME).cpp
sketch_elf := $(out_path)/$(SKETCH_NAME).elf
sketch_hex := $(out_path)/$(SKETCH_NAME).hex
sketch_o := $(out_path)/$(SKETCH_NAME).cpp.o
local_o := $(addprefix $(out_path)/,$(addsuffix .o,$(notdir $(wildcard *.cpp))))

# Core and libraries
include_flags := -I.
ifeq ($(TARGET_SYSTEM),uno)
include_flags += -I$(ARDUINO_AVR_PATH)/variants/standard
else ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
include_flags += -I$(ARDUINO_AVR_PATH)/variants/eightanaloginputs
endif
lib_out_paths :=
libs_o :=

define include_library =
include_flags += -I$(2)
lib_out_paths += $$(out_path)/$(1)
libs_o += $$(addprefix $$(out_path)/$(1)/,$$(addsuffix .o,\
	$$(notdir $$(wildcard $$(addprefix $(2)/*.,c cpp S)))))
endef

define handle_library =
ifneq (,$$(filter $(1),$$(INCLUDE_LIBS)))
ifeq (,$$(filter $(1),$$(_handled_libraries)))
ifneq (0,$$(words $$(wildcard $$(addprefix $(2)/*.,h c cpp S))))
_handled_libraries += $(1)
$$(eval $$(call $(3),$(1),$(2)))
else ifneq (0,$$(words $$(wildcard $$(addprefix $(2)/src/*.,h c cpp S))))
_handled_libraries += $(1)
$$(eval $$(call $(3),$(1),$(2)/src))
endif
endif
endif
endef

$(eval $(call include_library,core,$(ARDUINO_CORE_PATH)))
_handled_libraries :=
$(foreach path,$(LIBRARY_PATHS),$(eval \
	$(foreach name,$(notdir $(wildcard $(path)/*)),$(eval \
		$(call handle_library,$(name),$(path)/$(name),include_library)\
	))\
))

# Flags
c_common_flags = -g -Os -w -Wall $(defines) $(include_flags) \
	-ffunction-sections -fdata-sections -flto -fno-fat-lto-objects
CFLAGS = $(c_common_flags)
CXXFLAGS = $(c_common_flags) -fno-exceptions
SFLAGS = -x assembler-with-cpp
ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 tiny_85))
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
	rm -rfd $(out_path)

compile: $(out_path) $(lib_out_paths) $(sketch_hex)

upload: compile
	$(info #### Upload to $(TARGET_SYSTEM))
	$(AVRDUDE) -p $(mcu) -C $(avrdude_conf) -c $(UPLOAD_PROGRAMMER) $(UPLOAD_PORT_CONFIG) \
		-U flash:w:$(sketch_hex):i

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
ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 tiny_85))
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

# Compile library files
define compile_library =
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

$(eval $(call compile_library,core,$(ARDUINO_CORE_PATH)))
_handled_libraries :=
$(foreach path,$(LIBRARY_PATHS),$(eval \
	$(foreach name,$(notdir $(wildcard $(path)/*)),$(eval \
		$(call handle_library,$(name),$(path)/$(name),compile_library)\
	))\
))
