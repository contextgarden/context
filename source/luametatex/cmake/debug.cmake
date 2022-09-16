# When we run valgrind we need verbose binaries:
#
# valgrind -v --track-origins=yes --leak-check=full context ...

# add_compile_options(-pg)
# set(CMAKE_EXE_LINKER_FLAGS "-pg")

# In addition to the microsoft compiler alignment suggestions we can run on linux:
#
# pahole luametatex

# add_compile_options(-p -gdwarf)
# set(CMAKE_EXE_LINKER_FLAGS "-p -gdwarf")
