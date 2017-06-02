#==============================================================================
# Lightweight makefile for Arduino - olaf.ollgaard@gmail.com
#
# This makefile is made to be included from a simple Makefile with a few
# configuration parameters, where only SKETCH_NAME and TARGET_SYSTEM are
# required, e.g.:
# +--------------------------------------
# |SKETCH_NAME = Blink.ino
# |TARGET_SYSTEM = uno
# |INCLUDE_LIBS =
# |include ../makeArduino/makeArduino.mk
# +--------------------------------------
# All local .cpp files are compiled as well as the sketch file and
# the libraries specified in INCLUDE_LIBS
#
# Make targets: all build fullbuild mostlyclean realclean clean compile upload
#
# Core libraries used:
# uno, pro_trinket_5v: Libraries from Arudino IDE 1.8.1
# tiny_84, tiny_85: https://code.google.com/archive/p/arduino-tiny/

#--------------------------------------------------
# Configuration variables and their default values

# SKETCH_NAME : Bare sketch filename
# (sketch should be in the same directory as the makefile)
# If you want to use an .ino file, include the .ino suffix, else omit suffix
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
# -	All .h, .c, .cpp and .S files are included by default, but you can specify
#	per library which exact object files to include, e.g. for the Adafruit
#	Wire library, to include only Wire.cpp and utility/twi.c:
#LIBRARY_OBJS_Wire = Wire twi
# -	All subfolders that contain .h, .c, .cpp or .S files are recursed into
#	and added to the include path
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
# LIBRARY_PATHS : List of library root paths, in order of preference in case
#	of any libraries present in more than one place
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

#----------------------------------------------------------
# Utility method for handling libraries and any subfolders
# that contain .h, .c, .cpp or .S files

# Parameters: (function name, library name, library path)
define handle_library =
ifneq (,$$(filter $(2),$$(INCLUDE_LIBS)))
ifeq (,$$(filter $(2),$$(_handled_libraries)))
ifneq (0,$$(words $$(wildcard $$(addprefix $(3)/*.,h c cpp S))))
_handled_libraries += $(2)
$$(eval $$(call handle_folder,$(1),$(2),$(3)))
else ifneq (0,$$(words $$(wildcard $$(addprefix $(3)/src/*.,h c cpp S))))
_handled_libraries += $(2)
$$(eval $$(call handle_folder,$(1),$(2),$(3)/src))
endif
endif
endif
endef

# Parameters: (function name, name, path)
define handle_folder =
ifeq (,$$(filter .git .vscode $$(out_path),$(2)))
ifneq (0,$$(words $$(wildcard $$(addprefix $(3)/*.,h c cpp S))))
ifneq (/,$$(findstring /,$(2)))
$$(info # $(1) $(2):)
endif
$$(info #     $(3))
$$(eval $$(call $(1),$(2),$(3)))
$$(foreach sub,$$(notdir $$(wildcard $(3)/*)),\
	$$(eval $$(call handle_folder,$(1),$(2)/$$(sub),$(3)/$$(sub))))
endif
endif
endef

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
sketch_elf := $(out_path)/$(SKETCH_NAME).elf
sketch_hex := $(out_path)/$(SKETCH_NAME).hex
ifeq (.ino,$(suffix $(SKETCH_NAME)))
sketch_cpp := $(out_path)/$(SKETCH_NAME).cpp
objs_o := $(out_path)/$(SKETCH_NAME).cpp.o
else
objs_o :=
endif
obj_paths :=

# Core and libraries
include_flags := -I.
ifeq ($(TARGET_SYSTEM),uno)
include_flags += -I$(ARDUINO_AVR_PATH)/variants/standard
else ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
include_flags += -I$(ARDUINO_AVR_PATH)/variants/eightanaloginputs
endif

define include_folder =
ifneq (.,$(1))
include_flags += -I$(2)
obj_paths += $$(out_path)/$(1)
endif
ifneq (,$$(strip $$(LIBRARY_OBJS_$(1))))
_incl_srcs := $$(notdir $$(wildcard $$(foreach obj,$$(LIBRARY_OBJS_$(1)),$$(addprefix $(2)/$$(obj).,c cpp S))))
else
_incl_srcs := $$(notdir $$(wildcard $$(addprefix $(2)/*.,c cpp S)))
endif
ifneq (,$$(strip $$(_incl_srcs)))
$$(info #       + $$(_incl_srcs))
objs_o += $$(addprefix $$(out_path)/$$(if $$(filter-out .,$(1)),$(1)/),$$(addsuffix .o,$$(_incl_srcs)))
endif
endef

$(eval $(call handle_folder,include_folder,.,.))
$(eval $(call handle_folder,include_folder,core,$(ARDUINO_CORE_PATH)))
_handled_libraries :=
$(foreach path,$(LIBRARY_PATHS),$(eval \
	$(foreach name,$(notdir $(wildcard $(path)/*)),$(eval \
		$(call handle_library,include_folder,$(name),$(path)/$(name))\
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

.PHONY: all build fullbuild mostlyclean realclean clean compile nm dumpS upload

all: build upload

build: mostlyclean compile

fullbuild: realclean compile

mostlyclean:
	rm -f $(out_path)/*.*

realclean clean:
	rm -rfd $(out_path)

compile: $(out_path) $(obj_paths) $(sketch_hex)
	$(info # Read elf stats)
	readelf -S $(sketch_elf) | perl -ne 's/\.\w+\s+\K(?:\w+\s+){3}(\w+)\s+\w+\s+[B-Z]*A[B-Z]*(?:\s+\d+){3}\s*$$/: $$1\n/ and print'

nm:
	avr-nm --size-sort -r -C -S $(sketch_elf)

dumpS:
	avr-objdump -S -C $(sketch_elf) |less

upload: compile
	$(info # Upload to $(TARGET_SYSTEM))
	$(AVRDUDE) -p $(mcu) -C $(avrdude_conf) -c $(UPLOAD_PROGRAMMER) $(UPLOAD_PORT_CONFIG) \
		-U flash:w:$(sketch_hex):i

$(out_path):
	mkdir $@

# Convert elf to hex
$(sketch_hex): $(sketch_elf)
	$(info # Convert to $@)
	$(AVR_OBJCOPY) -O ihex -R .eeprom $< $@

# Link to elf
$(sketch_elf): $(objs_o)
	$(info # Link to $@)
	$(CC) -mmcu=$(mcu) -lm -Wl,--gc-sections -Os -o $@ $^

ifeq (.ino,$(suffix $(SKETCH_NAME)))
# Generate sketch .cpp from .ino
$(sketch_cpp): $(SKETCH_NAME)
	$(info # Generate $@)
ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 tiny_85))
	@echo '#include "WProgram.h"'>$@
else
	@echo '#include "Arduino.h"'>$@
endif
	@cat $< >> $@
# Compile sketch .cpp file
$(out_path)/%.cpp.o:: $(out_path)/%.cpp
	$(info # Compile $<)
	$(CXX) -c $(CXXFLAGS) $< -o $@
endif

# Compile .c, .cpp and .S files
define define_folder_rules =
ifneq (.,$(1))
$$(out_path)/$(1):
	mkdir $$@
endif
$$(out_path)/$$(if $$(filter-out .,$(1)),$(1)/)%.c.o:: $(2)/%.c
	$$(info # Compile $$<)
	$$(CC) -c $$(CFLAGS) $$< -o $$@
$$(out_path)/$$(if $$(filter-out .,$(1)),$(1)/)%.cpp.o:: $(2)/%.cpp
	$$(info # Compile $$<)
	$$(CXX) -c $$(CXXFLAGS) $$< -o $$@
$$(out_path)/$$(if $$(filter-out .,$(1)),$(1)/)%.S.o:: $(2)/%.S
	$$(info # Compile $$<)
	$$(CC) -c $$(SFLAGS) $$(CFLAGS) $$< -o $$@
endef

$(eval $(call handle_folder,define_folder_rules,.,.))
$(eval $(call handle_folder,define_folder_rules,core,$(ARDUINO_CORE_PATH)))
_handled_libraries :=
$(foreach path,$(LIBRARY_PATHS),$(eval \
	$(foreach name,$(notdir $(wildcard $(path)/*)),$(eval \
		$(call handle_library,define_folder_rules,$(name),$(path)/$(name))\
	))\
))
