#==============================================================================
# Lightweight makefile for Arduino - olaf.ollgaard@gmail.com
#
# This makefile is made to be included from a simple Makefile with a few
# configuration parameters, where only PROJECT_NAME and TARGET_SYSTEM are
# required, e.g.:
# +--------------------------------------
# |PROJECT_NAME = Sample
# |TARGET_SYSTEM = uno
# |INCLUDE_LIBS =
# |include ../makeArduino/makeArduino.mk
# +--------------------------------------
# All local .cpp files are compiled as well as the libraries specified in
# INCLUDE_LIBS. If PROJECT_NAME is an .ino filename, this is compiled too
#
# Make targets: all build fullbuild mostlyclean realclean clean compile upload
#
# Core libraries used:
# uno, pro_trinket_5v: Core from Arudino IDE 1.8.1
# tiny_84, tiny_85: https://code.google.com/archive/p/arduino-tiny/
# raw84, raw85: rawcore

#--------------------------------------------------
# Configuration variables and their default values

# PROJECT_NAME : Project name, used as name part of .elf and .hex filenames
# It can also be the filename (excl path, incl suffix) of an .ino sketch
# file, which should be placed in the same directory as the makefile
ifndef PROJECT_NAME
$(error !!!!! PROJECT_NAME must be defined)
endif

# TARGET_SYSTEM : uno | pro_trinket_5v | tiny_84 | tiny_85 | raw84 | raw85 | raw328
ifndef TARGET_SYSTEM
$(error !!!!! TARGET_SYSTEM must be defined)
else ifeq (,$(filter $(TARGET_SYSTEM),uno pro_trinket_5v tiny_84 tiny_85 raw84 raw85 raw328))
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

# PROJECT_DEFINES : Additional project-wide defines
#   e.g. PROJECT_DEFINES = MY_DEFINE_1 MY_DEFINE_2
PROJECT_DEFINES ?=

# ARDUINO_IDE_PATH : Path to arduino folder
ARDUINO_IDE_PATH ?= /home/$(USER)/arduino-1.8.1
# ARDUINO_TOOLS_PATH : Path to arduino build tools
ARDUINO_TOOLS_PATH ?= $(ARDUINO_IDE_PATH)/hardware/tools/avr/bin
# ARDUINO_AVR_PATH : Path to "hardware/arduino/avr" folder
ARDUINO_AVR_PATH ?= $(ARDUINO_IDE_PATH)/hardware/arduino/avr
# PACKAGES_PATH : Path to packages folder
PACKAGES_PATH ?= /home/$(USER)/.arduino15
# PROJECTS_ROOT_PATH : Path to the user projects root
PROJECTS_ROOT_PATH ?= /home/$(USER)/Arduino
# ARDUINO_CORE_PATH: Path to arduino core
ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 tiny_85))
ARDUINO_CORE_PATH ?= $(PROJECTS_ROOT_PATH)/tiny/avr/cores/tiny
else ifneq (,$(filter $(TARGET_SYSTEM),raw84 raw85 raw328))
ARDUINO_CORE_PATH ?= $(PROJECTS_ROOT_PATH)/rawcore
else
ARDUINO_CORE_PATH ?= $(ARDUINO_AVR_PATH)/cores/arduino
endif
# LIBRARY_PATHS : List of library root paths, in order of preference in case
#	of any libraries present in more than one place
LIBRARY_PATHS += $(PROJECTS_ROOT_PATH)/my_libraries $(PROJECTS_ROOT_PATH)/libraries
ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
LIBRARY_PATHS += $(PACKAGES_PATH)/adafruit/hardware/avr/1.4.9/libraries
endif
LIBRARY_PATHS += $(ARDUINO_AVR_PATH)/libraries $(ARDUINO_IDE_PATH)/libraries

# F_CPU : Target frequency in Hz
ifneq (,$(filter $(TARGET_SYSTEM),uno pro_trinket_5v))
F_CPU ?= 16000000
else
F_CPU ?= 8000000
endif

# UPLOAD_PORT : Port to use
# UPLOAD_PROGRAMMER : Programmer type for uploader
# UPLOAD_PORT_CONFIG : Port configuration for the uploader
UPLOAD_PORT ?= /dev/ttyACM0
ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
UPLOAD_PROGRAMMER = usbtiny
UPLOAD_PORT_CONFIG =
else ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 tiny_85 raw84 raw85 raw328))
UPLOAD_PROGRAMMER ?= stk500v1
UPLOAD_PORT_CONFIG ?= -b 19200 -P $(UPLOAD_PORT)
else
UPLOAD_PROGRAMMER ?= arduino
UPLOAD_PORT_CONFIG ?= -b 115200 -P $(UPLOAD_PORT)
endif

# FUSES_CONFIG : Fuses to "burn"
ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 tiny_85 raw84 raw85))
FUSES_CONFIG ?= -U efuse:w:0xff:m -U hfuse:w:0xdf:m -U lfuse:w:0xe2:m
endif
ifneq (,$(filter $(TARGET_SYSTEM),raw328))
FUSES_CONFIG ?= -U efuse:w:0xff:m -U hfuse:w:0xd9:m -U lfuse:w:0xe2:m
endif

# End of configuration section
#==============================================================================

#---------------------
# Compilers and tools

CC = $(ARDUINO_TOOLS_PATH)/avr-gcc
CXX = $(ARDUINO_TOOLS_PATH)/avr-g++
AVR_OBJCOPY = $(ARDUINO_TOOLS_PATH)/avr-objcopy
AVRDUDE = $(ARDUINO_TOOLS_PATH)/avrdude

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

ifneq (,$(filter $(TARGET_SYSTEM),uno pro_trinket_5v raw328))
mcu = atmega328p
else ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 raw84))
mcu = attiny84
else ifneq (,$(filter $(TARGET_SYSTEM),tiny_85 raw85))
mcu = attiny85
endif

# Defines
defines := -DF_CPU=$(F_CPU) -DARDUINO=10801 -DARDUINO_ARCH_AVR $(foreach def,$(PROJECT_DEFINES),$(patsubst %,-D%,$(def)))
ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
defines += -DARDUINO_AVR_PROTRINKET5
else ifneq (,$(filter $(TARGET_SYSTEM),uno raw328))
defines += -DARDUINO_AVR_UNO
else ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 tiny_85 raw84 raw85))
defines += -DARDUINO_attiny
endif

# Intermediate files
out_path := .mkout
project_elf := $(out_path)/$(PROJECT_NAME).elf
project_hex := $(out_path)/$(PROJECT_NAME).hex
ifeq (.ino,$(suffix $(PROJECT_NAME)))
project_cpp := $(out_path)/$(PROJECT_NAME).cpp
objs_o := $(out_path)/$(PROJECT_NAME).cpp.o
else
objs_o :=
endif
obj_paths :=
c_cpp_properties_json := $(out_path)/c_cpp_properties.json

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
c_common_flags = -g -Os -w -Wall -mmcu=$(mcu) $(defines) $(include_flags) \
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
avrdude_flags = -p $(mcu) -C /etc/avrdude.conf -c $(UPLOAD_PROGRAMMER) $(UPLOAD_PORT_CONFIG)

#-------------------
# Targets and rules

.PHONY: all burnfuses build fullbuild mostlyclean realclean clean compile nm dumpS upload

all: build upload

build: mostlyclean compile

fullbuild: realclean compile

mostlyclean:
	rm -f $(out_path)/*.*

realclean clean:
	rm -rfd $(out_path)

compile: $(out_path) $(obj_paths) $(c_cpp_properties_json) $(project_hex)
	$(info # Read elf stats)
	readelf -S $(project_elf) | perl -ne 's/\.\w+\s+\K(?:\w+\s+){3}(\w+)\s+\w+\s+[B-Z]*A[B-Z]*(?:\s+\d+){3}\s*$$/: $$1\n/ and print'
	@-diff -U 0 --color .vscode/c_cpp_properties.json $(c_cpp_properties_json)

nm:
	avr-nm --size-sort -r -C -S $(project_elf)

dumpS:
	avr-objdump -S -C $(project_elf) |less

burnfuses:
	$(info # "Burn" $(TARGET_SYSTEM) fuses)
	$(AVRDUDE) $(avrdude_flags) -e $(FUSES_CONFIG)

upload: compile
	$(info # Upload to $(TARGET_SYSTEM))
	$(AVRDUDE) $(avrdude_flags) -U flash:w:$(project_hex):i

$(out_path):
	mkdir $@

# Convert elf to hex
$(project_hex): $(project_elf)
	$(info # Convert to $@)
	$(AVR_OBJCOPY) -O ihex -R .eeprom $< $@

# Link to elf
$(project_elf): $(objs_o)
	$(info # Link to $@)
	$(CC) -mmcu=$(mcu) -lm -Wl,--gc-sections -Os -o $@ $(objs_o)

# Generate c_cpp_properties.json
$(c_cpp_properties_json):
	$(file > $@,{)
	$(file >> $@,  "configurations": [)
	$(file >> $@,    {)
	$(file >> $@,      "name": "Linux",)
	$(file >> $@,      "defines": [)
	$(foreach def,$(defines),$(file >> $@,        "$(def:-D%=%)",))
ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 tiny_85 raw84 raw85))
	$(file >> $@,        "__AVR_TINY__", "__AVR_TINY_PM_BASE_ADDRESS__=0",)
ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 raw84))
	$(file >> $@,        "__AVR_ATtiny84__", "__AVR_ATtinyX4__",)
else ifneq (,$(filter $(TARGET_SYSTEM),tiny_85 raw85))
	$(file >> $@,        "__AVR_ATtiny85__", "__AVR_ATtinyX5__",)
endif
endif
	$(file >> $@,        "__AVR_ARCH__")
	$(file >> $@,      ],)
	$(file >> $@,      "includePath": [)
	$(foreach path,$(include_flags),$(file >> $@,        "$(path:-I%=%)",))
	$(file >> $@,        "$(ARDUINO_TOOLS_PATH:%/bin=%)/avr/include")
	$(file >> $@,      ],)
	$(file >> $@,      "browse": {)
	$(file >> $@,        "limitSymbolsToIncludedHeaders": true,)
	$(file >> $@,        "databaseFilename": "",)
	$(file >> $@,        "path": [)
	$(foreach path,$(include_flags),$(file >> $@,          "$(path:-I%=%)",))
	$(file >> $@,          "$(ARDUINO_TOOLS_PATH:%/bin=%)/avr/include",)
	$(file >> $@,          "$${workspaceRoot}")
	$(file >> $@,        ])
	$(file >> $@,      },)
	$(file >> $@,      "intelliSenseMode": "clang-x64")
	$(file >> $@,    })
	$(file >> $@,  ],)
	$(file >> $@,  "version": 4)
	$(file >> $@,})
	perl -pi -e 's!^[\t ]+"\K/home/[^/"]+!~!' $@
	@-diff -U 0 --color .vscode/c_cpp_properties.json $(c_cpp_properties_json)

ifeq (.ino,$(suffix $(PROJECT_NAME)))
# Generate project .cpp from .ino
$(project_cpp): $(PROJECT_NAME)
	$(info # Generate $@)
ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 tiny_85))
	@echo '#include "WProgram.h"'>$@
else
	@echo '#include "Arduino.h"'>$@
endif
	@cat $< >> $@
# Compile project .cpp file
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
