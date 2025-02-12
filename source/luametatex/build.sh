# The official designated locations are:
#
# <texroot/tex/texmf-mswin/bin        <texroot/tex/texmf-win64/bin
# <texroot/tex/texmf-linux-32/bin     <texroot/tex/texmf-linux-64/bin
# <texroot/tex/texmf-linux-armhf/bin
#                                     <texroot/tex/texmf-osx-64/bin
# <texroot/tex/texmf-freebsd/bin      <texroot/tex/texmf-freebsd-amd64/bin
# <texroot/tex/texmf-openbsdX.Y/bin   <texroot/tex/texmf-openbsdX.Y-amd64/bin
#
# The above bin directory only needs:
#
# luametatex[.exe]
# context[.exe]    -> luametatex[.exe]
# mtxrun[.exe]     -> luametatex[.exe]
# mtxrun.lua       (latest version)
# context.lua      (latest version)

# This test is not yet okay but I have no time (or motivation) to look into it now, so for now we don't
# use ninja (not that critical).

#NINJA=$(which ninja);
#if (NINJA) then
#    NINJA="-G Ninja"
#else
    NINJA=""
#fi

if [ "$1" = "mingw-64" ] || [ "$1" = "mingw64" ] || [ "$1" = "mingw" ] || [ "$1" == "--mingw64" ]
then

    PLATFORM="win64"
    SUFFIX=".exe"
    mkdir -p build/mingw-64
    cd       build/mingw-64
    cmake $NINJA -DCMAKE_TOOLCHAIN_FILE=./cmake/mingw-64.cmake ../..

elif [ "$1" = "mingw-32" ] || [ "$1" = "mingw32" ] || [ "$1" == "--mingw32" ]
then

    PLATFORM="mswin"
    SUFFIX=".exe"
    mkdir -p build/mingw-32
    cd       build/mingw-32
    cmake $NINJA -DCMAKE_TOOLCHAIN_FILE=./cmake/mingw-32.cmake ../..

elif [ "$1" = "mingw-64-ucrt" ] || [ "$1" = "mingw64ucrt" ] || [ "$1" = "--mingw64ucrt" ]  || [ "$1" = "ucrt" ] || [ "$1" = "--ucrt" ]
then

    PLATFORM="win64"
    SUFFIX=".exe"
    mkdir -p build/mingw-64-ucrt
    cd       build/mingw-64-ucrt
    cmake $NINJA -DCMAKE_TOOLCHAIN_FILE=./cmake/mingw-64-ucrt.cmake ../..


elif [ "$1" = "cygwin" ] || [ "$1" = "--cygwin" ]
then

    PLATFORM="cygwin"
    SUFFIX=".exe"
    mkdir -p build/cygwin
    cd       build/cygwin
    cmake $NINJA ../..

elif [ "$1" = "osx-arm" ] || [ "$1" = "osxarm" ] || [ "$1" = "--osx-arm" ] || [ "$1" = "--osxarm" ]
then

    PLATFORM="osx-arm"
    SUFFIX="    "
    mkdir -p build/osx-arm
    cd       build/osx-arm
    cmake $NINJA -DCMAKE_OSX_ARCHITECTURES="arm64" ../..

elif [ "$1" = "osx-intel" ] || [ "$1" = "osxintel" ] || [ "$1" = "--osx-intel" ] || [ "$1" = "--osxintel" ]
then

    PLATFORM="osx-intel"
    SUFFIX="    "
    mkdir -p build/osx-intel
    cd       build/osx-intel
    cmake $NINJA -DCMAKE_OSX_ARCHITECTURES="x86_64" ../..

elif [ "$1" = "osx-universal" ] || [ "$1" = "osxuniversal" ] || [ "$1" = "--osx-universal" ] || [ "$1" = "--osxuniversal" ]
then

    PLATFORM="osx"
    SUFFIX="    "
    mkdir -p build/osx
    cd       build/osx
    cmake $NINJA -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" ../..

elif [ "$1" = "help" ] || [ "$1" = "--help" ]
then

echo ""
echo "platforms, optionally passed as argument:"
echo ""
echo "mingw-64"
echo "mingw-32"
echo "mingw-64-ucrt"
echo "cygwin"
echo "osx-arm"
echo "osx-intel"
echo "osx-universal"
echo ""
echo "default platform: native"
echo ""

exit 0

else

    PLATFORM="native"
    SUFFIX="    "
    mkdir -p build/native
    cd       build/native
    cmake $NINJA ../..

fi

#~ make -j8
cmake --build . --parallel 8

echo ""
echo "tex trees"
echo ""
echo "resources like public fonts  : tex/texmf/...."
echo "the context macro package    : tex/texmf-context/...."
echo "the luametatex binary        : tex/texmf-$PLATFORM/bin/..."
echo "optional third party modules : tex/texmf-context/...."
echo "fonts installed by the user  : tex/texmf-fonts/fonts/data/...."
echo "styles made by the user      : tex/texmf-projects/tex/context/user/...."
echo ""
echo "binaries:"
echo ""
echo "tex/texmf-<your platform>/bin/luametatex$SUFFIX : the compiled binary (some 3-4MB)"
echo "tex/texmf-<your platform>/bin/mtxrun$SUFFIX     : copy of or link to luametatex"
echo "tex/texmf-<your platform>/bin/context$SUFFIX    : copy of or link to luametatex"
echo "tex/texmf-<your platform>/bin/mtxrun.lua     : copy of tex/texmf-context/scripts/context/lua/mtxrun.lua"
echo "tex/texmf-<your platform>/bin/context.lua    : copy of tex/texmf-context/scripts/context/lua/context.lua"
echo ""
echo "commands:"
echo ""
echo "mtxrun --generate                 : create file database"
echo "mtxrun --script fonts --reload    : create font database"
echo "mtxrun --autogenerate context ... : run tex file (e.g. from editor)"
echo ""
