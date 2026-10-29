#!/bin/sh

set -eu

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
#
# for musl under wsl:
#
#    sudo apt update && sudo apt install musl-tools

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT_DIR"

EXTRA_CMAKE_ARGS=""
PROFILE=0
DEBUG=0
NOOPTIMIZE=0
PLATFORM_REQUEST="native"
SHOW_HELP=0

for ARGUMENT in "$@"; do
    case "$ARGUMENT" in
        debug|--debug)
            DEBUG=1
            ;;
        profile|--profile)
            PROFILE=1
            ;;
        nolto|--nolto|nooptimize|--nooptimize)
            NOOPTIMIZE=1
            ;;
        musl|--musl)
            PLATFORM_REQUEST="musl"
            ;;
        mingw-64|mingw64|mingw|--mingw64|ming64|--ming64)
            PLATFORM_REQUEST="mingw-64"
            ;;
        mingw-32|mingw32|--mingw32)
            PLATFORM_REQUEST="mingw-32"
            ;;
        mingw-64-ucrt|mingw64ucrt|--mingw64ucrt|ucrt|--ucrt)
            PLATFORM_REQUEST="mingw-64-ucrt"
            ;;
        cygwin|--cygwin)
            PLATFORM_REQUEST="cygwin"
            ;;
        aarch64|--aarch64|rpi|--rpi)
            PLATFORM_REQUEST="aarch64"
            ;;
        osx-arm|osxarm|--osx-arm|--osxarm)
            PLATFORM_REQUEST="osx-arm"
            ;;
        osx-intel|osxintel|--osx-intel|--osxintel)
            PLATFORM_REQUEST="osx-intel"
            ;;
        osx-universal|osxuniversal|--osx-universal|--osxuniversal)
            PLATFORM_REQUEST="osx-universal"
            ;;
        arm-64|arm64|--arm-64|--arm64)
            PLATFORM_REQUEST="arm64"
            ;;
        help|--help)
            SHOW_HELP=1
            ;;
        *)
            echo "unknown argument: $ARGUMENT" >&2
            exit 2
            ;;
    esac
done

if [ "$SHOW_HELP" -eq 1 ]; then
    echo ""
    echo "platforms, optionally passed as argument:"
    echo ""
    echo "mingw-64"
    echo "mingw-32"
    echo "mingw-64-ucrt"
    echo "cygwin"
    echo "aarch64"
    echo "osx-arm"
    echo "osx-intel"
    echo "osx-universal"
    echo ""
    echo "--debug       build without optimization"
    echo "--profile     build, train, and use profile-guided optimization"
    echo "--nooptimize  don't apply link-time-optimization (faster compile/test cycle)"
    echo "--musl        build a Linux binary using musl-gcc"
    echo ""
    echo "default platform: native"
    echo ""
    exit 0
fi

if [ "$DEBUG" -eq 1 ]; then
    EXTRA_CMAKE_ARGS="-DLMT_DEBUG=ON"
else
    EXTRA_CMAKE_ARGS="-DLMT_DEBUG=OFF"
fi

if [ "$NOOPTIMIZE" -eq 1 ]; then
    EXTRA_CMAKE_ARGS="-DLMT_NOOPTIMIZE=ON"
else
    EXTRA_CMAKE_ARGS="-DLMT_NOOPTIMIZE=OFF"
fi

if [ "$PROFILE" -eq 0 ]; then
    EXTRA_CMAKE_ARGS="$EXTRA_CMAKE_ARGS -DLMT_PROFILE=OFF"
fi

# Check if ninja or ninja-build exists on the system:

if command -v ninja >/dev/null 2>&1 || command -v ninja-build >/dev/null 2>&1; then
    NINJA="-G Ninja"
else
    NINJA=""
fi

if [ "$PROFILE" -eq 1 ] &&
    [ "$PLATFORM_REQUEST" != "native" ] &&
    [ "$PLATFORM_REQUEST" != "mingw-64" ] &&
    [ "$PLATFORM_REQUEST" != "aarch64" ]; then
    echo "--profile currently supports the native and mingw-64 platforms only" >&2
    exit 2
fi

PROFILE_MODE="OFF"
PROFILE_DIR=""
PROFILE_COMPILER=""
PROFILE_BUILD_DIR=""
PROFILE_RUNTIME_DIR=""
PROFILE_TARGET=""

if [ "$PROFILE" -eq 1 ]; then
    if [ "$DEBUG" -eq 1 ]; then
        echo "--profile cannot be combined with --debug" >&2
        exit 2
    fi

    case "$PLATFORM_REQUEST" in
        native|aarch64)
            PROFILE_TARGET="native"
            PROFILE_CC_DEFAULT="cc"
            ;;
        mingw-64)
            PROFILE_TARGET="mingw64"
            PROFILE_CC_DEFAULT="x86_64-w64-mingw32-gcc"
            ;;
    esac

    PROFILE_CC="${CC:-${CMAKE_C_COMPILER:-$PROFILE_CC_DEFAULT}}"
    if ! command -v "$PROFILE_CC" >/dev/null 2>&1; then
        echo "--profile compiler not found: $PROFILE_CC" >&2
        exit 2
    fi
    PROFILE_CC_VERSION=$(
        {
            "$PROFILE_CC" --version
            "$PROFILE_CC" -v
        } 2>&1 || true
    )
    case "$PROFILE_CC_VERSION" in
        *[Cc][Ll][Aa][Nn][Gg]*)
            PROFILE_COMPILER="clang"
            ;;
        *[Gg][Cc][Cc]*)
            PROFILE_COMPILER="gcc"
            ;;
        *)
            echo "--profile requires a GCC or Clang compiler (selected: $PROFILE_CC)" >&2
            exit 2
            ;;
    esac

    if [ -z "${LMT_CONTEXT_BIN:-}" ] ||
       [ -z "${LMT_MANUAL_LUAMETATEX:-}" ]; then
        echo "--profile requires LMT_CONTEXT_BIN, LMT_MANUAL_LUAMETATEX, and optionally LMT_MANUAL_LUAMETAFUN and LMT_MANUAL_MATHINCONTEXT" >&2
        exit 2
    fi

    PROFILE_MODE="GENERATE"
    if [ "$PROFILE_TARGET" = "native" ]; then
        # Keep the original native profile location stable.
        PROFILE_DIR="$ROOT_DIR/profiles/$PROFILE_COMPILER/data"
        PROFILE_BUILD_DIR="$ROOT_DIR/build/profile-$PROFILE_COMPILER"
    else
        PROFILE_DIR="$ROOT_DIR/profiles/$PROFILE_COMPILER/$PROFILE_TARGET/data"
        PROFILE_BUILD_DIR="$ROOT_DIR/build/profile-$PROFILE_TARGET-$PROFILE_COMPILER"
    fi

  # PROFILE_RUNTIME_DIR="${LMT_PROFILE_RUNTIME_DIR:-}" # This one will go.
    if [ -z "$PROFILE_RUNTIME_DIR" ]; then
        if [ "$PROFILE_TARGET" = "mingw64" ]; then
            if ! command -v wslpath >/dev/null 2>&1; then
                echo "--profile --mingw64 requires WSL's wslpath (or LMT_PROFILE_RUNTIME_DIR)" >&2
                exit 2
            fi
            if ! PROFILE_RUNTIME_DIR=$(wslpath -m "$PROFILE_DIR"); then
                echo "cannot convert the profile directory to a Windows path: $PROFILE_DIR" >&2
                exit 2
            fi
        else
            PROFILE_RUNTIME_DIR="$PROFILE_DIR"
        fi
    fi

    # Profile data is compiler- and source-dependent. A new --profile run
    # always starts cleanly, so a failed or old training run cannot be reused.
    rm -rf "$PROFILE_DIR"
    mkdir -p "$PROFILE_DIR" "$PROFILE_BUILD_DIR"
fi

case "$PLATFORM_REQUEST" in
    mingw-64)
        PLATFORM="win64"
        SUFFIX=".exe"
        BUILD_DIR="$ROOT_DIR/build/mingw-64"
        CMAKE_PLATFORM_ARGS="-DCMAKE_TOOLCHAIN_FILE=$ROOT_DIR/cmake/mingw-64.cmake"
        ;;
    mingw-32)
        PLATFORM="mswin"
        SUFFIX=".exe"
        BUILD_DIR="$ROOT_DIR/build/mingw-32"
        CMAKE_PLATFORM_ARGS="-DCMAKE_TOOLCHAIN_FILE=$ROOT_DIR/cmake/mingw-32.cmake"
        ;;
    mingw-64-ucrt)
        PLATFORM="win64"
        SUFFIX=".exe"
        BUILD_DIR="$ROOT_DIR/build/mingw-64-ucrt"
        CMAKE_PLATFORM_ARGS="-DCMAKE_TOOLCHAIN_FILE=$ROOT_DIR/cmake/mingw-64-ucrt.cmake"
        ;;
    cygwin)
        PLATFORM="cygwin"
        SUFFIX=".exe"
        BUILD_DIR="$ROOT_DIR/build/cygwin"
        CMAKE_PLATFORM_ARGS=""
        ;;
    aarch64)
        PLATFORM="aarch64"
        SUFFIX=""
        BUILD_DIR="$ROOT_DIR/build/aarch64"
        CMAKE_PLATFORM_ARGS=""
        ;;
    osx-arm)
        PLATFORM="osx-arm"
        SUFFIX=""
        BUILD_DIR="$ROOT_DIR/build/osx-arm"
        CMAKE_PLATFORM_ARGS="-DCMAKE_OSX_ARCHITECTURES=arm64"
        ;;
    osx-intel)
        PLATFORM="osx-intel"
        SUFFIX=""
        BUILD_DIR="$ROOT_DIR/build/osx-intel"
        CMAKE_PLATFORM_ARGS="-DCMAKE_OSX_ARCHITECTURES=x86_64"
        ;;
    osx-universal)
        PLATFORM="osx"
        SUFFIX=""
        BUILD_DIR="$ROOT_DIR/build/osx"
        CMAKE_PLATFORM_ARGS="-DCMAKE_OSX_ARCHITECTURES=arm64;x86_64"
        ;;
    arm64)
        PLATFORM="arm64"
        SUFFIX=".exe"
        BUILD_DIR="$ROOT_DIR/build/arm64"
        CMAKE_PLATFORM_ARGS="-DCMAKE_TOOLCHAIN_FILE=$ROOT_DIR/cmake/arm64.cmake"
        ;;
    musl)
        PLATFORM="linux-musl"
        SUFFIX=""
        BUILD_DIR="$ROOT_DIR/build/musl"
        CMAKE_PLATFORM_ARGS="-DCMAKE_C_COMPILER=musl-gcc"
        ;;
    native)
        PLATFORM="native"
        SUFFIX=""
        if [ "$PROFILE" -eq 1 ]; then
            BUILD_DIR="$PROFILE_BUILD_DIR"
        else
            BUILD_DIR="$ROOT_DIR/build/native"
        fi
        CMAKE_PLATFORM_ARGS=""
        ;;
esac

if [ "$PROFILE" -eq 1 ] && [ "$PROFILE_TARGET" != "native" ]; then
    BUILD_DIR="$PROFILE_BUILD_DIR"
fi

if [ "$PROFILE" -eq 1 ]; then
    CONTEXT_BIN="${LMT_CONTEXT_BIN}"
    PROFILE_DOC_LUAMETATEX="${LMT_MANUAL_LUAMETATEX}"
    PROFILE_DOC_LUAMETAFUN="${LMT_MANUAL_LUAMETAFUN:-}"
    PROFILE_DOC_MATHINCONTEXT="${LMT_MANUAL_MATHINCONTEXT:-}"
    PATH="$CONTEXT_BIN:$PATH"
    export PATH

    run_cmake() {
        cmake $NINJA $CMAKE_PLATFORM_ARGS \
            "-DLMT_PROFILE=$PROFILE_MODE" \
            "-DLMT_PROFILE_DIR=$PROFILE_DIR" \
            "-DLMT_PROFILE_RUNTIME_DIR=$PROFILE_RUNTIME_DIR" \
            -S "$ROOT_DIR" \
            -B "$BUILD_DIR"
    }
else
    run_cmake() {
        cmake $NINJA $CMAKE_PLATFORM_ARGS $EXTRA_CMAKE_ARGS \
            "-DLMT_DEBUG=$DEBUG" \
            "-DLMT_NOOPTIMIZE=$NOOPTIMIZE" \
            -S "$ROOT_DIR" \
            -B "$BUILD_DIR"
    }
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
run_cmake

cmake --build . --parallel 8

if [ "$PROFILE" -eq 1 ]; then
    PROFILE_BINARY="$BUILD_DIR/luametatex$SUFFIX"
    PROFILE_ENGINE="$CONTEXT_BIN/luametatex$SUFFIX"
    PROFILE_CONTEXT="$CONTEXT_BIN/context$SUFFIX"
    if [ ! -x "$PROFILE_BINARY" ]; then
        echo "profile build did not produce $PROFILE_BINARY" >&2
        exit 1
    fi
    if [ ! -d "$CONTEXT_BIN" ]; then
        echo "ConTeXt bin directory is not available: $CONTEXT_BIN" >&2
        exit 1
    fi
    if [ ! -f "$CONTEXT_BIN/mtxrun.lua" ] || [ ! -f "$CONTEXT_BIN/context.lua" ]; then
        echo "ConTeXt Lua runners are not available in $CONTEXT_BIN" >&2
        exit 1
    fi

    install_profile_binary() {
        cp "$PROFILE_BINARY" "$PROFILE_ENGINE"
        if [ "$SUFFIX" = ".exe" ]; then
            # Windows installations normally contain copies rather than Unix
            # symlinks. Make every runner use the instrumented executable.
            cp "$PROFILE_BINARY" "$PROFILE_CONTEXT"
            cp "$PROFILE_BINARY" "$CONTEXT_BIN/mtxrun.exe"
        fi
    }

    install_profile_binary
    if [ ! -x "$PROFILE_CONTEXT" ]; then
        echo "ConTeXt context runner is not executable: $PROFILE_CONTEXT" >&2
        exit 1
    fi

    if [ "$PROFILE_COMPILER" = "clang" ]; then
        if [ "$PROFILE_TARGET" = "mingw64" ]; then
            LLVM_PROFILE_FILE="$PROFILE_RUNTIME_DIR/luametatex-%p.profraw"
        else
            LLVM_PROFILE_FILE="$PROFILE_DIR/luametatex-%p.profraw"
        fi
        export LLVM_PROFILE_FILE
    else
        unset LLVM_PROFILE_FILE 2>/dev/null || true
    fi

    # Helper function to execute context via CMD console script when targeting MinGW in WSL
    run_context_command() {

        echo ""
        echo "== profiling ================================"
        echo ""
        echo LMT_SETUP_CMD            : ${LMT_SETUP_CMD:-}
        echo LMT_CONTEXT_BIN          : ${LMT_CONTEXT_BIN:-}
        echo LMT_MANUAL_LUAMETATEX    : ${LMT_MANUAL_LUAMETATEX:-}
        echo LMT_MANUAL_LUAMETAFUN    : ${LMT_MANUAL_LUAMETAFUN:-}
        echo LMT_MANUAL_MATHINCONTEXT : ${LMT_MANUAL_MATHINCONTEXT:-}
        echo LMT_PROFILE_RUNTIME_DIR  : ${LMT_PROFILE_RUNTIME_DIR:-}
        echo ""
        echo "============================================="
        echo ""

        if [ "$PLATFORM_REQUEST" = "mingw-64" ] && command -v cmd.exe >/dev/null 2>&1; then

            WIN_PWD=$(wslpath -m "$PWD")
            WIN_BIN=$(wslpath -m "$CONTEXT_BIN")

            # Build the exact command string (check / \ etc)

            CMD_STR="c:/data/setup/console-wsl.cmd && context.exe $*"

            if [ -z "${LMT_SETUP_CMD:-}" ]; then
                LMT_SETUP_CMD="<unset>"
                CMD_STR="context.exe $*"
            else
                CMD_STR="$LMT_SETUP_CMD && context.exe $*"
            fi

            # Trace the inputs and command string

            echo ""
            echo "== windows setup ============================"
            echo ""
            echo "PWD (Linux)   : $PWD"
            echo "PWD (Windows) : $WIN_PWD"
            echo "BIN (Linux)   : $CONTEXT_BIN"
            echo "BIN (Windows) : $WIN_BIN"
            echo "CMD           : $CMD_STR"
            echo "Executing CMD : cmd.exe /C \"$CMD_STR\""
            echo ""
            echo "============================================="

            cmd.exe /C "$CMD_STR"
        else
            "$PROFILE_CONTEXT" "$@"
        fi
    }

    # Generate format files and process training documents
    run_context_command --make

    for PROFILE_DOCUMENT in "$PROFILE_DOC_LUAMETATEX" "$PROFILE_DOC_LUAMETAFUN" "$PROFILE_DOC_MATHINCONTEXT"; do
        if [ -z "$PROFILE_DOCUMENT" ]; then
            continue
        fi
        if [ ! -f "$PROFILE_DOCUMENT" ]; then
            echo "profile document not found: $PROFILE_DOCUMENT" >&2
            continue
          # exit 1
        fi
        PROFILE_DOCUMENT_DIR=$(dirname "$PROFILE_DOCUMENT")
        PROFILE_DOCUMENT_NAME=$(basename "$PROFILE_DOCUMENT")
        (
            cd "$PROFILE_DOCUMENT_DIR"
            run_context_command "$PROFILE_DOCUMENT_NAME"
        )
    done

    if [ "$PROFILE_COMPILER" = "gcc" ]; then
        if [ -z "$(find "$PROFILE_DIR" -type f -name '*.gcda' -print | sed -n '1p')" ]; then
            echo "GCC did not produce profile data in $PROFILE_DIR" >&2
            exit 1
        fi
    else
        if [ -z "$(find "$PROFILE_DIR" -type f -name '*.profraw' -print | sed -n '1p')" ]; then
            echo "Clang did not produce raw profile data in $PROFILE_DIR" >&2
            exit 1
        fi
        LLVM_PROFDATA="${LLVM_PROFDATA:-llvm-profdata}"
        if ! command -v "$LLVM_PROFDATA" >/dev/null 2>&1; then
            echo "llvm-profdata is required to use Clang profiles" >&2
            exit 1
        fi
        "$LLVM_PROFDATA" merge \
            -output="$PROFILE_DIR/luametatex.profdata" \
            "$PROFILE_DIR"/*.profraw
    fi

    # CMake refuses a USE configuration without this completion marker.
    # It is created only after all training commands and profile conversion
    # have succeeded.
    touch "$PROFILE_DIR/profile.ready"

    PROFILE_MODE="USE"
    run_cmake
    cmake --build . --parallel 8

    install_profile_binary
    run_context_command --make
    echo "profile-guided build complete ($PROFILE_COMPILER)"
fi

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
echo "tex/texmf-<your platform>/bin/luametatex$SUFFIX : the compiled binary (some 4-5MB)"
echo "tex/texmf-<your platform>/bin/mtxrun$SUFFIX     : copy of or link to luametatex"
echo "tex/texmf-<your platform>/bin/context$SUFFIX    : copy of or link to luametatex"
echo ""
echo "tex/texmf-<your platform>/bin/mtxrun.lua  : copy of tex/texmf-context/scripts/context/lua/mtxrun.lua"
echo "tex/texmf-<your platform>/bin/context.lua : copy of tex/texmf-context/scripts/context/lua/context.lua"
echo ""
echo "commands:"
echo ""
echo "mtxrun --generate                 : create file database"
echo "mtxrun --script fonts --reload    : create font database"
echo "mtxrun --autogenerate context ... : run tex file (e.g. from editor)"
echo ""

if [ "$DEBUG" -eq 1 ]; then
    echo "gdb --args ./tex/texmf-linux-64/bin/luametatex --your-tex-file.tex"
    echo ""
    echo "(gdb) run"
    echo "# ... wait for crash ..."
    echo "(gdb) backtrace"
    echo ""
fi