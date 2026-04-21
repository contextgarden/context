# /*********************************************************************/
# /*       fi_lib  --- A fast interval library (Makefile)              */
# /*       (For copyright and info`s look at file "fi_lib.h")          */
# /*********************************************************************/

#----------- Start checking here ----------------------------------------
CC = gcc#          !!! name of your C compiler   (e.g. gcc, cc, xlc, ...) 
CPP = g++#         !!! name of your C++ compiler (e.g. g++, CC, xlC, ...)
CFLAGS = #         !!! options for your C/C++ Compiler (for HP: -Aa) 
COPT = #           !!! optimization options (e.g. -O2, -O, ...)
#                  !!! Caution! These options can cause problems!
#
T = test#          !!! test program directory
E = example#       !!! directory with example programs
#----------- Stop checking here -----------------------------------------

# Default and clean up rules
#---------------------------
default: 
	@echo "Usage: make help | all | test | clean | <sample program name>"
	@echo
	@echo "Sample programs: $(PRJ1)  $(PRJ2)  $(PRJ3)  $(PRJ4) $(PRJ5)"
	@echo "                 $(PRJ6)  $(PRJ7)"
	@echo

# Help on adaptation of this make file
#-------------------------------------
help: default
	@echo "For adaptation of this make file to your system, edit file Makefile"
	@echo "and adapt the definitions of the following macro variables:"
	@echo
	@echo "   CC        : command to invoke your C compiler"
	@echo "   CPP       : command to invoke your C++ compiler"
	@echo "   CFLAGS    : options for your C/C++ compiler"
	@echo "   COPT      : optimization options for your C/C++ compiler"
	@echo
	
# Delete all *.o *.a and executable files
#----------------------------------------
clean:	
	@rm -f *.a *.o
	@find example -perm -111 -type f -exec rm {} \;
	@find test -perm -111 -type f -exec rm {} \;


LIB = fi_lib.a

# Rules for generating exceutables of the sample programs
#--------------------------------------------------------
PRJ1  = fi_test
PRJ2  = hornerc
PRJ3  = comp_sin
PRJ4  = comp_exp
PRJ5  = hornercpp
PRJ6  = bisection
PRJ7  = xinewton

LIBRARIES =  $(LIB) -lm

$(PRJ1): $(LIB) $(T)/$(PRJ1).c
	$(CC) $(CFLAGS) -o $(T)/$(PRJ1) -I. $(T)/$(PRJ1).c $(LIBRARIES)
# Here no $(COPT), because -O2 cause problems on some maschines!

$(PRJ2): $(LIB) $(E)/$(PRJ2).c
	$(CC) $(CFLAGS) $(COPT) -o $(E)/$(PRJ2) -I. $(E)/$(PRJ2).c $(LIBRARIES)

$(PRJ3): $(LIB) $(E)/$(PRJ3).c
	$(CC) $(CFLAGS) $(COPT) -o $(E)/$(PRJ3) -I. $(E)/$(PRJ3).c $(LIBRARIES)

$(PRJ4): $(LIB) $(E)/$(PRJ4).c
	$(CC) $(CFLAGS) $(COPT) -o $(E)/$(PRJ4) -I. $(E)/$(PRJ4).c $(LIBRARIES)

$(PRJ5): $(LIB) $(E)/$(PRJ5).C
	$(CPP) $(CFLAGS) $(COPT) -o $(E)/$(PRJ5) -I. $(E)/$(PRJ5).C $(LIBRARIES)

$(PRJ6): $(LIB) $(E)/$(PRJ6).C
	$(CPP) $(CFLAGS) $(COPT) -o $(E)/$(PRJ6) -I. $(E)/$(PRJ6).C $(LIBRARIES)

$(PRJ7): $(LIB) $(E)/$(PRJ7).C
	$(CPP) $(CFLAGS) $(COPT) -o $(E)/$(PRJ7) -I. $(E)/$(PRJ7).C $(LIBRARIES)

ALL_PROGRAMS = $(PRJ1)  $(PRJ2)  $(PRJ3)  $(PRJ4)  $(PRJ5)  $(PRJ6) $(PRJ7)  

OBJECTS = j_acos.o j_acsh.o j_acot.o j_acth.o j_asin.o j_asnh.o j_atan.o \
          j_atnh.o j_cos.o j_cosh.o j_cot.o j_coth.o j_exp.o j_ex10.o j_exp2.o \
          j_expm.o j_log.o j_lg10.o j_lg1p.o j_log2.o j_sin.o j_sinh.o j_sqr.o \
          j_sqrt.o j_tan.o j_tanh.o j_erf.o q_acos.o q_acsh.o q_acot.o q_acth.o \
          q_asin.o q_asnh.o q_atan.o q_atnh.o q_atn1.o q_cos.o q_cos1.o \
          q_cosh.o q_cot.o q_coth.o q_ep1.o q_epm1.o q_exp.o q_ex10.o q_exp2.o \
          q_expm.o q_glbl.o q_log.o q_log1.o q_lg10.o q_log2.o q_pred.o \
          q_rtrg.o q_sin.o q_sin1.o q_sinh.o q_sqr.o q_sqrt.o q_succ.o q_tan.o \
          q_tanh.o q_cth1.o q_erf.o q_scan.o q_prnt.o q_ari.o q_errm.o q_comp.o 

$(LIB): $(OBJECTS)
	ar rv $@ $(OBJECTS)

%.o: %.c fi_lib.h
	$(CC) -c $(CFLAGS) $(COPT) $<


all: $(LIB) $(ALL_PROGRAMS)	
	@echo
	@echo "the library and all sample programs are (now) up-to-date"
	@echo

test: $(PRJ1)
	$(T)/$(PRJ1)
