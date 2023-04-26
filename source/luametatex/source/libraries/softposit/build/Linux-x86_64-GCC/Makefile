#============================================================================
#
#This C source file is part of the SoftPosit Posit Arithmetic Package
#by S. H. Leong (Cerlane).
#
#Copyright 2017, 2018 A*STAR.  All rights reserved.
#
#This C source file was based on SoftFloat IEEE Floating-Point Arithmetic
#Package, Release 3d, by John R. Hauser.
#
#
# Copyright 2011, 2012, 2013, 2014, 2015, 2016, 2017 The Regents of the
# University of California.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  1. Redistributions of source code must retain the above copyright notice,
#     this list of conditions, and the following disclaimer.
#
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions, and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
#  3. Neither the name of the University nor the names of its contributors
#     may be used to endorse or promote products derived from this software
#     without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS", AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ARE
# DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#=============================================================================

SOURCE_DIR ?= ../../source
PYTHON_DIR ?= ../../python
SPECIALIZE_TYPE ?= 8086-SSE
COMPILER ?= gcc

SOFTPOSIT_OPTS ?=  \
  -DINLINE_LEVEL=5 #\
  -DSOFTPOSIT_QUAD -lquadmath 

COMPILE_PYTHON = \
  $(COMPILER) -fPIC -c $(PYTHON_DIR)/softposit_python_wrap.c \
		-I/usr/include/python \
		-I$(SOURCE_DIR)/include -I.
COMPILE_PYTHON3 = \
  $(COMPILER) -fPIC -c $(PYTHON_DIR)/softposit_python_wrap.c \
		-I/usr/include/python3 \
		-I$(SOURCE_DIR)/include -I.
LINK_PYTHON = \
  ld -shared  *.o -o $(PYTHON_DIR)/_softposit.so


ifeq ($(OS),Windows_NT)
     DELETE = del /Q /F
else
     DELETE = rm -f
endif

C_INCLUDES = -I. -I$(SOURCE_DIR)/$(SPECIALIZE_TYPE) -I$(SOURCE_DIR)/include
OPTIMISATION  = -O2 #-march=core-avx2
COMPILE_C = \
  $(COMPILER) -c -Werror-implicit-function-declaration -DSOFTPOSIT_FAST_INT64 \
    $(SOFTPOSIT_OPTS) $(C_INCLUDES) $(OPTIMISATION) \
    -o $@ 
MAKELIB = ar crs $@
MAKESLIB = $(COMPILER) -shared $^

OBJ = .o
LIB = .a
SLIB = .so

.PHONY: all
all: softposit$(LIB)

quad: SOFTPOSIT_OPTS+= -DSOFTPOSIT_QUAD -lquadmath
quad: all

python2: SOFTPOSIT_OPTS+= -fPIC
python2: all
	$(COMPILE_PYTHON)
	$(LINK_PYTHON)
	
python3: SOFTPOSIT_OPTS+= -fPIC
python3: all
	$(COMPILE_PYTHON3)
	$(LINK_PYTHON)

julia: SOFTPOSIT_OPTS+= -fPIC
julia: softposit$(SLIB)



OBJS_PRIMITIVES = 

OBJS_SPECIALIZE = 

OBJS_OTHERS = \
  s_addMagsP8$(OBJ) \
  s_subMagsP8$(OBJ) \
  s_mulAddP8$(OBJ) \
  p8_add$(OBJ) \
  p8_sub$(OBJ) \
  p8_mul$(OBJ) \
  p8_div$(OBJ) \
  p8_sqrt$(OBJ) \
  p8_to_p16$(OBJ) \
  p8_to_p32$(OBJ) \
  p8_to_pX2$(OBJ) \
  p8_to_i32$(OBJ) \
  p8_to_i64$(OBJ) \
  p8_to_ui32$(OBJ) \
  p8_to_ui64$(OBJ) \
  p8_roundToInt$(OBJ) \
  p8_mulAdd$(OBJ) \
  p8_eq$(OBJ) \
  p8_le$(OBJ) \
  p8_lt$(OBJ) \
  quire8_fdp_add$(OBJ) \
  quire8_fdp_sub$(OBJ) \
  ui32_to_p8$(OBJ) \
  ui64_to_p8$(OBJ) \
  i32_to_p8$(OBJ) \
  i64_to_p8$(OBJ) \
  s_addMagsP16$(OBJ) \
  s_subMagsP16$(OBJ) \
  s_mulAddP16$(OBJ) \
  p16_to_ui32$(OBJ) \
  p16_to_ui64$(OBJ) \
  p16_to_i32$(OBJ) \
  p16_to_i64$(OBJ) \
  p16_to_p8$(OBJ) \
  p16_to_p32$(OBJ) \
  p16_to_pX2$(OBJ) \
  p16_roundToInt$(OBJ) \
  p16_add$(OBJ) \
  p16_sub$(OBJ) \
  p16_mul$(OBJ) \
  p16_mulAdd$(OBJ) \
  p16_div$(OBJ) \
  p16_eq$(OBJ) \
  p16_le$(OBJ) \
  p16_lt$(OBJ) \
  p16_sqrt$(OBJ) \
  quire16_fdp_add$(OBJ) \
  quire16_fdp_sub$(OBJ) \
  quire_helper$(OBJ) \
  ui32_to_p16$(OBJ) \
  ui64_to_p16$(OBJ) \
  i32_to_p16$(OBJ) \
  i64_to_p16$(OBJ) \
  s_addMagsP32$(OBJ) \
  s_subMagsP32$(OBJ) \
  s_mulAddP32$(OBJ) \
  p32_to_ui32$(OBJ) \
  p32_to_ui64$(OBJ) \
  p32_to_i32$(OBJ) \
  p32_to_i64$(OBJ) \
  p32_to_p8$(OBJ) \
  p32_to_p16$(OBJ) \
  p32_to_pX2$(OBJ) \
  p32_roundToInt$(OBJ) \
  p32_add$(OBJ) \
  p32_sub$(OBJ) \
  p32_mul$(OBJ) \
  p32_mulAdd$(OBJ) \
  p32_div$(OBJ) \
  p32_eq$(OBJ) \
  p32_le$(OBJ) \
  p32_lt$(OBJ) \
  p32_sqrt$(OBJ) \
  quire32_fdp_add$(OBJ) \
  quire32_fdp_sub$(OBJ) \
  ui32_to_p32$(OBJ) \
  ui64_to_p32$(OBJ) \
  i32_to_p32$(OBJ) \
  i64_to_p32$(OBJ) \
  s_approxRecipSqrt_1Ks$(OBJ) \
  c_convertDecToPosit8$(OBJ) \
  c_convertPosit8ToDec$(OBJ) \
  c_convertDecToPosit16$(OBJ) \
  c_convertPosit16ToDec$(OBJ) \
  c_convertQuire8ToPosit8$(OBJ) \
  c_convertQuire16ToPosit16$(OBJ) \
  c_convertQuire32ToPosit32$(OBJ) \
  c_convertDecToPosit32$(OBJ) \
  c_convertPosit32ToDec$(OBJ) \
  c_int$(OBJ) \
  s_addMagsPX2$(OBJ) \
  s_subMagsPX2$(OBJ) \
  s_mulAddPX2$(OBJ) \
  pX2_add$(OBJ) \
  pX2_sub$(OBJ) \
  pX2_mul$(OBJ) \
  pX2_div$(OBJ) \
  pX2_mulAdd$(OBJ) \
  pX2_roundToInt$(OBJ) \
  pX2_sqrt$(OBJ) \
  pX2_eq$(OBJ) \
  pX2_le$(OBJ) \
  pX2_lt$(OBJ) \
  ui32_to_pX2$(OBJ) \
  ui64_to_pX2$(OBJ) \
  i32_to_pX2$(OBJ) \
  i64_to_pX2$(OBJ) \
  c_convertQuireX2ToPositX2$(OBJ) 
 

OBJS_ALL := $(OBJS_PRIMITIVES) $(OBJS_SPECIALIZE) $(OBJS_OTHERS) 

$(OBJS_ALL): \
  platform.h \
  $(SOURCE_DIR)/include/primitives.h
 
$(OBJS_SPECIALIZE) $(OBJS_OTHERS): \
  $(SOURCE_DIR)/include/softposit_types.h $(SOURCE_DIR)/include/internals.h \
  $(SOURCE_DIR)/$(SPECIALIZE_TYPE)/specialize.h \
  $(SOURCE_DIR)/include/softposit.h 

$(OBJS_PRIMITIVES) $(OBJS_OTHERS): %$(OBJ): $(SOURCE_DIR)/%.c
	$(COMPILE_C) $(SOURCE_DIR)/$*.c

$(OBJS_SPECIALIZE): %$(OBJ): $(SOURCE_DIR)/$(SPECIALIZE_TYPE)/%.c
	$(COMPILE_C) $(SOURCE_DIR)/$(SPECIALIZE_TYPE)/$*.c

softposit$(LIB): $(OBJS_ALL) 
	$(MAKELIB) $^
	
softposit$(SLIB): $(OBJS_ALL) 
	$(MAKESLIB) -o $@


.PHONY: clean
clean:
	$(DELETE) $(OBJS_ALL) softposit_python_wrap.o softposit$(LIB) softposit$(SLIB)

