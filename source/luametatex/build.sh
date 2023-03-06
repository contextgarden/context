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

if [ "$1" = "mingw-64" ] || [ "$1" = "mingw64" ] || [ "$1" = "mingw" ] || [ "$1" == "--mingw64" ]
then

    PLATFORM="win64"
    SUFFIX=".exe"
    mkdir -p build/mingw-64
    cd       build/mingw-64
    cmake -G Ninja -DCMAKE_TOOLCHAIN_FILE=./cmake/mingw-64.cmake ../..

elif [ "$1" = "mingw-32" ] || [ "$1" = "mingw32" ] || [ "$1" == "--mingw32" ]
then

    PLATFORM="mswin"
    SUFFIX=".exe"
    mkdir -p build/mingw-32
    cd       build/mingw-32
    cmake -G Ninja -DCMAKE_TOOLCHAIN_FILE=./cmake/mingw-32.cmake ../..

elif [ "$1" = "mingw-64-ucrt" ] || [ "$1" = "mingw64ucrt" ] || [ "$1" = "--mingw64ucrt" ]  || [ "$1" = "ucrt" ] || [ "$1" = "--ucrt" ] 
then

    PLATFORM="win64"
    SUFFIX=".exe"
    mkdir -p build/mingw-64-ucrt
    cd       build/mingw-64-ucrt
    cmake -G Ninja -DCMAKE_TOOLCHAIN_FILE=./cmake/mingw-64-ucrt.cmake ../..

else

    PLATFORM="native"
    SUFFIX="    "
    mkdir -p build/native
    cd       build/native
    cmake -G Ninja ../..

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
echo "tex/texmf-<your platform>/bin/luametatex$SUFFIX : the compiled binary (some 2-3MB)"
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
