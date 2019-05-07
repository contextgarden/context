mkdir build-mingw-32
cd    build-mingw-32

export MAKEFLAGS=-j8

cmake -DCMAKE_TOOLCHAIN_FILE=./cmake/mingw-32.cmake ../source

make
