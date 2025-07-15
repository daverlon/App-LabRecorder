@echo off
REM Set variables for paths
set "LSL_DIR=C:\Program Files (x86)\liblsl\lib\cmake\LSL"
set "Qt_DIR=C:\Qt\6.7.3\msvc2022_64\lib\cmake\Qt6"

REM Add Qt bin folder to PATH for find_package to work properly
set "PATH=C:\Qt\6.7.3\msvc2022_64\bin;%PATH%"

REM Create build directory if not exists
if not exist build mkdir build
cd build

REM Run CMake to configure project
cmake .. -G "Visual Studio 17 2022" -A x64 ^
    -DQt6_DIR="%Qt_DIR%" ^
    -DLSL_DIR="%LSL_DIR%"

IF %ERRORLEVEL% NEQ 0 (
    echo CMake configuration failed.
    pause
    exit /b 1
)

REM Build project in Release configuration
cmake --build . --config Release

IF %ERRORLEVEL% NEQ 0 (
    echo Build failed.
    pause
    exit /b 1
)

echo Build succeeded! You can find the output in build\Release
pause
