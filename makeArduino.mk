#==============================================================================
# Lightweight makefile for Arduino - olaf.ollgaard@gmail.com
#
# This makefile is made to be included from a simple Makefile with a few
# configuration parameters, where only TARGET_SYSTEM is required, e.g.:
# +--------------------------------------
# |TARGET_SYSTEM = uno
# |INCLUDE_LIBS =
# |include ../makeArduino/makeArduino.mk
# +--------------------------------------
# All local .cpp files are compiled as well as the libraries specified in
# INCLUDE_LIBS
#
# Make targets: all build fullbuild mostlyclean realclean clean compile upload
#
# Core libraries used:
# uno, pro_trinket_5v: Core from Arudino IDE 1.8.1
# tiny_84, tiny_85: https://code.google.com/archive/p/arduino-tiny/
# (default): rawcore

#--------------------------------------------------
# Configuration variables and their default values

PROJECT_NAME = $(notdir $(abspath .))

ifndef TARGET_SYSTEM
$(error !!!!! TARGET_SYSTEM must be defined)
else ifeq (,$(filter $(TARGET_SYSTEM), \
	uno \
	pro_trinket_5v \
	pro_micro_5v \
	itsybitsy_32u4 \
	tiny_84 tiny_85 \
	raw84 raw85 raw328p raw32u4))
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
ARDUINO_TOOLS_PATH ?= $(ARDUINO_IDE_PATH)/hardware/tools/avr
# ARDUINO_AVR_PATH : Path to "hardware/arduino/avr" folder
ARDUINO_AVR_PATH ?= $(ARDUINO_IDE_PATH)/hardware/arduino/avr
# PACKAGES_PATH : Path to packages folder
PACKAGES_PATH ?= /home/$(USER)/.arduino15
# PROJECTS_ROOT_PATH : Path to the user projects root
PROJECTS_ROOT_PATH ?= /home/$(USER)/Arduino
# ARDUINO_CORE_PATH: Path to arduino core
ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 tiny_85))
ARDUINO_CORE_PATH ?= $(PROJECTS_ROOT_PATH)/tiny/avr/cores/tiny
else ifneq (,$(filter $(TARGET_SYSTEM),uno, pro_trinket_5v))
ARDUINO_CORE_PATH ?= $(ARDUINO_AVR_PATH)/cores/arduino
else
ARDUINO_CORE_PATH ?= $(PROJECTS_ROOT_PATH)/rawcore
endif
# LIBRARY_PATHS : List of library root paths, in order of preference in case
#	of any libraries present in more than one place
LIBRARY_PATHS += $(PROJECTS_ROOT_PATH)/my_libraries $(PROJECTS_ROOT_PATH)/libraries
ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
LIBRARY_PATHS += $(PACKAGES_PATH)/adafruit/hardware/avr/1.4.9/libraries
endif
LIBRARY_PATHS += $(ARDUINO_AVR_PATH)/libraries $(ARDUINO_IDE_PATH)/libraries

# F_CPU : Target frequency in Hz
ifneq (,$(filter $(TARGET_SYSTEM),\
	uno \
	pro_trinket_5v \
	pro_micro_5v \
	itsybitsy_32u4))
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
else ifeq ($(TARGET_SYSTEM),uno)
UPLOAD_PROGRAMMER ?= arduino
UPLOAD_PORT_CONFIG ?= -b 115200 -P $(UPLOAD_PORT)
else
UPLOAD_PROGRAMMER ?= stk500v1
UPLOAD_PORT_CONFIG ?= -b 19200 -P $(UPLOAD_PORT)
endif

# FUSES_CONFIG : Fuses to "burn"
ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 tiny_85 raw84 raw85))
FUSES_CONFIG ?= -U efuse:w:0xff:m -U hfuse:w:0xdf:m -U lfuse:w:0xe2:m
endif
ifneq (,$(filter $(TARGET_SYSTEM),raw328p))
FUSES_CONFIG ?= -U efuse:w:0xff:m -U hfuse:w:0xd9:m -U lfuse:w:0xe2:m
endif

# End of configuration section
#==============================================================================

#---------------------
# Compilers and tools

CC = $(ARDUINO_TOOLS_PATH)/bin/avr-gcc
CXX = $(ARDUINO_TOOLS_PATH)/bin/avr-g++
AVR_OBJCOPY = $(ARDUINO_TOOLS_PATH)/bin/avr-objcopy
AVRDUDE = $(ARDUINO_TOOLS_PATH)/bin/avrdude

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

ifneq (,$(filter $(TARGET_SYSTEM),uno pro_trinket_5v pro_micro_5v raw328p))
mcu = atmega328p
else ifneq (,$(filter $(TARGET_SYSTEM),raw32u4 itsybitsy_32u4))
mcu = atmega32u4
else ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 raw84))
mcu = attiny84
else ifneq (,$(filter $(TARGET_SYSTEM),tiny_85 raw85))
mcu = attiny85
endif

# Defines
defines := -DF_CPU=$(F_CPU) -DARDUINO=10801 -DARDUINO_ARCH_AVR $(foreach def,$(PROJECT_DEFINES),$(patsubst %,-D%,$(def)))
ifeq ($(TARGET_SYSTEM),pro_trinket_5v)
defines += -DARDUINO_AVR_PROTRINKET5
else ifeq ($(TARGET_SYSTEM),uno)
defines += -DARDUINO_AVR_UNO
else ifneq (,$(filter $(TARGET_SYSTEM),tiny_84 tiny_85))
defines += -DARDUINO_attiny
endif

# Intermediate files
out_path := .mkout
project_elf := $(out_path)/$(PROJECT_NAME).elf
project_hex := $(out_path)/$(PROJECT_NAME).hex
objs_o :=
obj_paths :=
vscode_path := .vscode
tasks_json_fname := tasks.json
tasks_json := $(out_path)/$(tasks_json_fname)
tasks_json_vscode := $(vscode_path)/$(tasks_json_fname)
c_cpp_json_fname := c_cpp_properties.json
c_cpp_json := $(out_path)/$(c_cpp_json_fname)
c_cpp_json_vscode := $(vscode_path)/$(c_cpp_json_fname)

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
avrdude_flags = -p $(mcu) -C $(ARDUINO_TOOLS_PATH)/etc/avrdude.conf -c $(UPLOAD_PROGRAMMER) $(UPLOAD_PORT_CONFIG)

#-------------------
# Targets and rules

.PHONY: all burnfuses build fullbuild mostlyclean realclean clean compile upload \
	buildvscode updatevscode \
	buildvscodecpp updatevscodecpp \
	buildvscodetasks updatevscodetasks \
	nm dumpS

all: build upload

build: mostlyclean compile

fullbuild: realclean compile

mostlyclean:
	rm -f $(out_path)/*.*

realclean clean:
	rm -rfd $(out_path)

buildvscode: buildvscodecpp buildvscodetasks

updatevscode: updatevscodecpp updatevscodetasks

buildvscodecpp: $(c_cpp_json) $(vscode_path)
	@-diff -U 0 --color $(c_cpp_json_vscode) $(c_cpp_json)

updatevscodecpp: buildvscodecpp
	cp $(c_cpp_json) $(c_cpp_json_vscode)

buildvscodetasks: $(tasks_json) $(vscode_path)
	@-diff -U 0 --color $(tasks_json_vscode) $(tasks_json)

updatevscodetasks: buildvscodetasks
	cp $(tasks_json) $(tasks_json_vscode)

compile: $(out_path) $(obj_paths) $(vscode_path) $(tasks_json) $(c_cpp_json) $(project_hex)
	$(info # Read elf stats)
	readelf -S $(project_elf) | perl -ne 's/\.\w+\s+\K(?:\w+\s+){3}(\w+)\s+\w+\s+[B-Z]*A[B-Z]*(?:\s+\d+){3}\s*$$/: $$1\n/ and print'
	@-diff -U 0 --color $(tasks_json_vscode) $(tasks_json)
	@-diff -U 0 --color $(c_cpp_json_vscode) $(c_cpp_json)

ifndef FUSES_CONFIG
burnfuses:
	$(error !!!!! FUSES_CONFIG not defined)
else
burnfuses:
	$(info # "Burn" $(TARGET_SYSTEM) fuses)
	$(AVRDUDE) $(avrdude_flags) -e $(FUSES_CONFIG)
endif

upload: compile
	$(info #)
	$(info # Upload to $(TARGET_SYSTEM))
	$(AVRDUDE) $(avrdude_flags) -U flash:w:$(project_hex):i

nm:
	avr-nm --size-sort -r -C -S $(project_elf)

dumpS:
	avr-objdump -S -C $(project_elf) |less

$(out_path):
	mkdir $@

$(vscode_path):
	mkdir $@

# Convert elf to hex
$(project_hex): $(project_elf)
	$(info #)
	$(info # Convert to $@)
	$(AVR_OBJCOPY) -O ihex -R .eeprom $< $@

# Link to elf
$(project_elf): $(objs_o)
	$(info #)
	$(info # Link to $@)
	$(CC) -mmcu=$(mcu) -lm -Wl,--gc-sections -Os -o $@ $(objs_o)

# Generate tasks.json
$(tasks_json): Makefile | $(out_path)
	$(file > $@,{)
	$(file >> $@,	// See https://go.microsoft.com/fwlink/?LinkId=733558)
	$(file >> $@,	// for the documentation about the tasks.json format)
	$(file >> $@,	"version": "2.0.0",)
	$(file >> $@,	"tasks": [)
	$(file >> $@,		{)
	$(file >> $@,			"label": "Build $(PROJECT_NAME)",)
	$(file >> $@,			"command": "make",)
	$(file >> $@,			"args": [)
	$(file >> $@,				"fullbuild")
	$(file >> $@,			],)
	$(file >> $@,			"group": {)
	$(file >> $@,				"kind": "build",)
	$(file >> $@,				"isDefault": true)
	$(file >> $@,			},)
	$(file >> $@,			"presentation": {)
	$(file >> $@,				"echo": true,)
	$(file >> $@,				"reveal": "always",)
	$(file >> $@,				"focus": false,)
	$(file >> $@,				"panel": "shared",)
	$(file >> $@,				"showReuseMessage": true,)
	$(file >> $@,				"clear": true)
	$(file >> $@,			},)
	$(file >> $@,			"problemMatcher": "$$gcc")
	$(file >> $@,		},)
	$(file >> $@,		{)
	$(file >> $@,			"label": "Upload $(PROJECT_NAME)",)
	$(file >> $@,			"command": "make",)
	$(file >> $@,			"args": [)
	$(file >> $@,				"upload")
	$(file >> $@,			],)
	$(file >> $@,			"presentation": {)
	$(file >> $@,				"echo": true,)
	$(file >> $@,				"reveal": "always",)
	$(file >> $@,				"focus": false,)
	$(file >> $@,				"panel": "shared",)
	$(file >> $@,				"showReuseMessage": true,)
	$(file >> $@,				"clear": true)
	$(file >> $@,			},)
	$(file >> $@,			"problemMatcher":"$$gcc")
	$(file >> $@,		},)
	$(file >> $@,		{)
	$(file >> $@,			"label": "Update .vscode/c_cpp_properties.json",)
	$(file >> $@,			"command": "make",)
	$(file >> $@,			"args": [)
	$(file >> $@,				"updatevscodecpp")
	$(file >> $@,			],)
	$(file >> $@,			"presentation": {)
	$(file >> $@,				"echo": true,)
	$(file >> $@,				"reveal": "always",)
	$(file >> $@,				"focus": false,)
	$(file >> $@,				"panel": "shared",)
	$(file >> $@,				"showReuseMessage": true,)
	$(file >> $@,				"clear": true)
	$(file >> $@,			},)
	$(file >> $@,			"problemMatcher":"$$gcc")
	$(file >> $@,		})
	$(file >> $@,	])
	$(file >> $@,})

# Generate c_cpp_properties.json
$(c_cpp_json): Makefile | $(out_path)
	$(file > $@,{)
	$(file >> $@,  "configurations": [)
	$(file >> $@,    {)
	$(file >> $@,      "name": "Linux",)
	$(file >> $@,      "defines": [)
	$(foreach def,$(defines),$(file >> $@,        "$(def:-D%=%)",))
ifneq (,$(filter $(mcu),attiny84 attiny85))
	$(file >> $@,        "__AVR_TINY__", "__AVR_TINY_PM_BASE_ADDRESS__=0",)
ifneq (,$(filter $(mcu),attiny84))
	$(file >> $@,        "__AVR_ATtiny84__", "__AVR_ATtinyX4__",)
else ifneq (,$(filter $(mcu),attiny85))
	$(file >> $@,        "__AVR_ATtiny85__", "__AVR_ATtinyX5__",)
endif
else ifneq (,$(filter $(mcu),atmega328p))
	$(file >> $@,        "__AVR_MEGA__", "__AVR_ATmega328P__",)
else ifneq (,$(filter $(mcu),atmega32u4))
	$(file >> $@,        "__AVR_MEGA__", "__AVR_ATmega32U4__",)
endif
ifneq (,$(filter $(mcu),attiny84 attiny85))
	$(file >> $@,        "__AVR_ARCH__=25")
else ifneq (,$(filter $(mcu),atmega328p atmega32u4))
	$(file >> $@,        "__AVR_ARCH__=5")
else
	$(file >> $@,        "__AVR_ARCH__")
endif
	$(file >> $@,      ],)
	$(file >> $@,      "includePath": [)
	$(foreach path,$(include_flags),$(file >> $@,        "$(path:-I%=%)",))
	$(file >> $@,        "$(ARDUINO_TOOLS_PATH)/avr/include")
	$(file >> $@,      ],)
	$(file >> $@,      "browse": {)
	$(file >> $@,        "limitSymbolsToIncludedHeaders": true,)
	$(file >> $@,        "databaseFilename": "",)
	$(file >> $@,        "path": [)
	$(foreach path,$(include_flags),$(file >> $@,          "$(path:-I%=%)",))
	$(file >> $@,          "$(ARDUINO_TOOLS_PATH)/avr/include",)
	$(file >> $@,          "$${workspaceRoot}")
	$(file >> $@,        ])
	$(file >> $@,      },)
	$(file >> $@,      "intelliSenseMode": "clang-x64")
	$(file >> $@,    })
	$(file >> $@,  ],)
	$(file >> $@,  "version": 4)
	$(file >> $@,})
	perl -pi -e 's!^[\t ]+"\K/home/[^/"]+!~!' $@

# Compile .c, .cpp and .S files
define define_folder_rules =
ifneq (.,$(1))
$$(out_path)/$(1):
	mkdir $$@
endif
$$(out_path)/$$(if $$(filter-out .,$(1)),$(1)/)%.c.o:: $(2)/%.c
	$$(info #)
	$$(info # Compile $$<)
	$$(CC) -c $$(CFLAGS) $$< -o $$@
$$(out_path)/$$(if $$(filter-out .,$(1)),$(1)/)%.cpp.o:: $(2)/%.cpp
	$$(info #)
	$$(info # Compile $$<)
	$$(CXX) -c $$(CXXFLAGS) $$< -o $$@
$$(out_path)/$$(if $$(filter-out .,$(1)),$(1)/)%.S.o:: $(2)/%.S
	$$(info #)
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
