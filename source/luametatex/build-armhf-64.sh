mkdir build-armhf-64
cd    build-armhf-64

export MAKEFLAGS=-j8

cmake -DCMAKE_TOOLCHAIN_FILE=./cmake/armhf-64.cmake ../source

make
