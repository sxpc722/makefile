SHELL := /bin/sh

CC := clang
CXX := clang++
CFLAGS := -W -O3 -pthread -mavx2
CPPFLAGS :=
CXXFLAGS :=

INCLUDE := 

TARGET_ARCH := 


LDLIBS := 
LDFLAGS := -pthread # -rpath

CL_FLAGS := -W -emit-llvm -cl-std=CL2.0
CL_TARGET_ARCH := -target spir64-unknown-unknown
CL_INCLUDE := -Xclang -finclude-default-header


COMPILE.cl = $(CC) $(CL_FLAGS) $(CL_TARGET_ARCH) -c
LLVM_SPV := llvm-spirv
LLVM_SPV_FLAGS := --spirv-ocl-builtins-version=CL2.0
LINK.spv = spirv-link

DIR_SRC := .
DIR_BLD := ./build
DIR_OBJ := $(DIR_BLD)/objs/
DIR_BIN := $(DIR_BLD)/bin/
DIR_LIB := $(DIR_BLD)/lib/

DIRS := $(shell find $(DIR_SRC) -mindepth 1 -path $(DIR_BLD) -prune -o -type d -print)
DIRS := $(DIRS:=/)
SUB_DIRS := $(shell find $(DIR_SRC) -mindepth 1 -maxdepth 1 -path $(DIR_BLD) -prune -o -type d -print)
SUB_DIRS := $(SUB_DIRS:=/)

MKDIR := $(shell mkdir -p $(DIRS:$(DIR_SRC)%=$(DIR_OBJ)%) $(DIR_BIN) $(DIR_LIB))

EXCLUDE :=
DEPS :=
TARGETS :=

all : target


define Auto_Generic =
dirs := $(filter $(1)%,$(DIRS))
src_c := $$(foreach d,$$(dirs),$$(wildcard $$(d)*.c))
src_cl := $$(foreach d,$$(dirs),$$(wildcard $$(d)*.cl))
obj_c := $$(src_c:$$(DIR_SRC)/%.c=$$(DIR_OBJ)%.o)
obj_cl := $$(src_cl:$$(DIR_SRC)/%.cl=$$(DIR_OBJ)%.spv)
DEPS += $$(obj_cl:=.d) $$(obj_c:=.d)

ifeq (,$$(filter $(1),$$(EXCLUDE)))

ifneq (,$$(strip $$(src_c)$$(src_cl)))
name := $(notdir $(1:/=))

ifneq ($$(filter lib%,$$(name)),)
ifneq ($$(filter libcl%,$$(name)),)
name := $$(DIR_LIB)$$(name).spv
else
name := $$(DIR_LIB)$$(name).so
$$(obj_c): CFLAGS += -fPIC
endif
else
name := $$(DIR_BIN)$$(name)
endif
$$(name) : $$(obj_c) $$(obj_cl)
TARGETS += $$(name)
endif

endif
endef

$(foreach s,$(SUB_DIRS),$(eval $(call Auto_Generic,$(s))))

-include $(DEPS)
$(DIR_OBJ)%.o.d : $(DIR_SRC)/%.c
	$(CC) -MM -MQ $(@:.d=) $< -MF $@
$(DIR_OBJ)%.spv.d : $(DIR_SRC)/%.cl
	$(CC) -MM -MQ $(@:.d=) $< -MF $@



$(DIR_OBJ)%.o :
	$(COMPILE.c) $< $(INCLUDE) $(OUTPUT_OPTION)

$(DIR_LIB)%.so : LDFLAGS += -shared
$(DIR_BIN)% $(DIR_LIB)%.so :
	$(LINK.o) $^ $(LOADLIBES) $(LDLIBS) -o $@

$(DIR_OBJ)%.spv:
	$(COMPILE.cl) $(CL_INCLUDE) $< -o $@ && $(LLVM_SPV) $(LLVM_SPV_FLAGS) $@ -o $@

$(DIR_LIB)%.spv:
	$(LINK.spv) $^ -o $@


target : $(TARGETS)

.PHONY: all clean debug
clean :
	-$(RM) -r $(DIR_BLD)

debug :
	echo $(TARGETS)
