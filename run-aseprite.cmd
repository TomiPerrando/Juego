@echo off
setlocal
set "ASEPRITE_EXE=%~dp0aseprite\build\bin\aseprite.exe"

if not exist "%ASEPRITE_EXE%" (
  echo Aseprite executable not found: "%ASEPRITE_EXE%"
  exit /b 1
)

start "" "%ASEPRITE_EXE%" %*
