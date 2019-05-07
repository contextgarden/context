mkdir build-mingw-64
cd    build-mingw-64

export MAKEFLAGS=-j8

cmake -DCMAKE_TOOLCHAIN_FILE=./cmake/mingw-64.cmake ../source

make
