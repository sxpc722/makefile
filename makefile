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

DIR_ROOT := $(CURDIR)
DIR_SRC := $(CURDIR)
DIR_BLD := $(DIR_ROOT)/build
DIR_OBJ := $(DIR_BLD)/objs$(DIR_SRC:$(DIR_ROOT)%=%)/
DIR_BIN := $(DIR_BLD)/bin$(DIR_SRC:$(DIR_ROOT)%=%)/
DIR_LIB := $(DIR_BLD)/lib$(DIR_SRC:$(DIR_ROOT)%=%)/

SUB_MAKE_DIR := $(dir $(shell find $(DIR_SRC) -mindepth 2  -path '$(DIR_BLD)/*' -prune -o -iname makefile -type f -print))
DIRS := $(shell find $(DIR_SRC) -mindepth 1 -path $(DIR_BLD) -prune -o -type d -print)
DIRS := $(DIRS:=/)
SUB_DIRS := $(shell find $(DIR_SRC) -mindepth 1 -maxdepth 1 -path $(DIR_BLD) -prune -o -type d -print)
SUB_DIRS := $(SUB_DIRS:=/)
OBJDIR :=$(DIRS:$(DIR_SRC)/%=$(DIR_OBJ)%)

EXCLUDE :=
DEPS :=
TARGETS :=

all :

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
$(DEPS) :|$(OBJDIR)
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




.PHONY: all clean debug $(SUB_MAKE_DIR)

all :$(TARGETS) $(SUB_MAKE_DIR) 

$(TARGETS) :|$(DIR_BIN) $(DIR_LIB)

$(SUB_MAKE_DIR) :
	@+$(MAKE) DIR_ROOT=$(DIR_ROOT) -C $@

define Clean_Sub =
	@+$(MAKE) DIR_ROOT=$(DIR_ROOT) -C $(1) clean
endef
clean :
	$(foreach d,$(SUB_MAKE_DIR),$(call Clean_Sub,$(d)))
	-$(RM) -r $(DIR_BIN) $(DIR_LIB) $(DIR_OBJ)

debug :
	echo $(TARGETS)

#mkdir for output
$(OBJDIR) $(DIR_BIN) $(DIR_LIB):
	@mkdir -p $@
