mkdir build-linux-32
cd    build-linux-32

export MAKEFLAGS=-j8

cmake -DCMAKE_TOOLCHAIN_FILE=./cmake/linux-32.cmake ../source

make
