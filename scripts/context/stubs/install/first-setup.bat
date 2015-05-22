@echo off

setlocal

:fetch

set OWNPATH=%~dp0
set PATH=%OWNPATH%bin;%PATH%
set PLATFORM=mswin

set CYGWIN=nontsec

if defined ProgramFiles(x86) (
    set PLATFORM=win64
) else (
    if "%PROCESSOR_ARCHITEW6432%"=="AMD64" set PLATFORM=win64
)

REM ~ copy /y bin\mtx-update.lua bin\x.lua

if "%PLATFORM%" == "win64" goto update-win64

:update-win32

rsync -av --exclude 'rsync.exe' --exclude 'cygwin1.dll' --exclude 'cygiconv-2.dll' rsync://contextgarden.net/minimals/setup/mswin/bin/ bin

goto update

:update-win64

rsync -av --exclude 'rsync.exe' --exclude 'cygwin1.dll' --exclude 'cygiconv-2.dll' rsync://contextgarden.net/minimals/setup/win64/bin/ bin

goto update

:update

REM ~ copy /y bin\x.lua bin\mtx-update.lua

REM --mingw --nofiledatabase --engine=luatex

mtxrun --script ./bin/mtx-update.lua --update --force --make --engine=all --context=beta --texroot="%OWNPATH%tex" %*

echo.
echo.
echo When you want to use context, you need to initialize the tree with:
echo.
echo   %OWNPATH%tex\setuptex.bat %OWNPATH%tex
echo.
echo You can associate this command with a shortcut to the cmd prompt.
echo.
echo Alternatively you can add %OWNPATH%tex\texmf-%PLATFORM%\bin to your PATH
echo variable.
echo.
echo If you run from an editor you can specify the full path to mtxrun.exe:
echo.
echo.  %OWNPATH%tex\texmf-%PLATFORM%\bin\mtxrun.exe --autogenerate --script context --autopdf ...
echo.

:ruby

echo okay > ok.log

ruby -e "File.delete('ok.log')"

if not exist "ok.log" goto end

echo.
echo The distribution has been downloaded but if you want to run pdfTeX and/or XeTeX you
echo need to run this script with the following directive:
echo.
echo   --platform=all
echo.
echo You then also need to install Ruby in order to be able to use texexec. After
echo installing Ruby you can run this script again which will give you the formats
echo needed, or you can run:
echo.
echo   texexec --make --pdftex
echo   texexec --make --xetex
echo.

:okay

del /q ok.log

:end

endlocal
