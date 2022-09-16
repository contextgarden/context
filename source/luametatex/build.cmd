rem  When something fails, make sure to remove the cmake cache. When compile from
rem  the Visual Studio environment mixed with compiling from the command line
rem  some confusion can occur.

setlocal

@echo .
@echo supported flags     : --arm64 --x64 --x86 --intel64 --intel86
@echo .

set luametatexsources=%~dp0
set luametatexplatform=x64
set msvcplatform=x64

for %%G in (%*) do (
    if [%%G] == [--arm64] (
        set luametatexplatform=arm64
        set msvcplatform=x86_arm64
    )
    if [%%G] == [--intel64] (
        set luametatexplatform=x64
        set msvcplatform=amd64
    )
    if [%%G] == [--intel86] (
        set luametatexplatform=x86
        set msvcplatform=x86_amd64
    )
    if [%%G] == [--x64] (
        set luametatexplatform=x64
        set msvcplatform=amd64
    )
    if [%%G] == [--x86] (
        set luametatexplatform=x86
        set msvcplatform=x86_amd64
    )
)

set visualstudiopath=c:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build
set luametatexbuildpath=msvc-cmd-%luametatexplatform%-release

@echo .
@echo luametatexplatform  : %luametatexplatform%
@echo msvcplatform        : %msvcplatform%
@echo visualstudiopath    : %visualstudiopath%
@echo luametatexbuildpath : %luametatexbuildpath%
@echo .

mkdir build
chdir build
rmdir /S /Q %luametatexbuildpath%
mkdir %luametatexbuildpath%
chdir %luametatexbuildpath%

call "%visualstudiopath%\vcvarsall.bat" %msvcplatform%

cmake ../..
cmake --build . --config Release  --parallel 8

cd ..
cd ..

dir build\%luametatexbuildpath%\Release\luametatex.exe

@echo .
@echo tex trees:
@echo .
@echo resources like public fonts  : tex/texmf/....
@echo the context macro package    : tex/texmf-context/....
@echo the luametatex binary        : tex/texmf-win64/bin/...
@echo optional third party modules : tex/texmf-context/....
@echo fonts installed by the user  : tex/texmf-fonts/fonts/data/....
@echo styles made by the user      : tex/texmf-projects/tex/context/user/....
@echo .
@echo binaries:
@echo .
@echo tex/texmf-win64/bin/luametatex.exe : the compiled binary (some 2-3MB)
@echo tex/texmf-win64/bin/mtxrun.exe     : copy of or link to luametatex.exe
@echo tex/texmf-win64/bin/context.exe    : copy of or link to luametatex.exe
@echo tex/texmf-win64/bin/mtxrun.lua     : copy of tex/texmf-context/scripts/context/lua/mtxrun.lua
@echo tex/texmf-win64/bin/context.lua    : copy of tex/texmf-context/scripts/context/lua/context.lua
@echo .
@echo commands:
@echo .
@echo mtxrun --generate                 : create file database
@echo mtxrun --script fonts --reload    : create font database
@echo mtxrun --autogenerate context ... : run tex file (e.g. from editor)
@echo .

endlocal
