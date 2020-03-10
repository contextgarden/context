@echo off

rem chcp 65001

rem I need to figure out how to detach the instance

start "vs code context" code --reuse-window --extensions-dir  %~dp0\extensions --install-extension context %* 2>&1 nul
