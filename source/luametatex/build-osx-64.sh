mkdir build-osx-64
cd    build-osx-64

export MAKEFLAGS=-j8

cmake -DCMAKE_TOOLCHAIN_FILE=./cmake/osx-64.cmake ../source

make
