mkdir build-openbsd-64
cd    build-openbsd-64

export MAKEFLAGS=-j8

cmake -DCMAKE_TOOLCHAIN_FILE=./cmake/openbsd-64.cmake ../source

make
