mkdir build-linux-64
cd    build-linux-64

export MAKEFLAGS=-j8

cmake -DCMAKE_TOOLCHAIN_FILE=./cmake/linux-64.cmake ../source

make
