mkdir build-freebsd-64
cd    build-freebsd-64

export MAKEFLAGS=-j8

cmake -DCMAKE_TOOLCHAIN_FILE=./cmake/freebsd-64.cmake ../source

make
