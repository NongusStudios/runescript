@echo off
set output=bin\debug\runescript.exe
set release_output=bin\release\runescript.exe

if "%~1"=="release" (
    odin build src -o:speed -out:%release_output%
) else (
    odin build src -debug -out:%output%
)