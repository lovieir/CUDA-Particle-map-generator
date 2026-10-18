@echo off
setlocal

rem Always build in the folder containing this script.
cd /d "%~dp0"
if errorlevel 1 goto :error

call "D:\visual studio\product\VC\Auxiliary\Build\vcvars64.bat"
if errorlevel 1 goto :error

nvcc "particleMapImagegenerator.cu" -o "particleMapImageGenerator.exe" -I "D:\vcpkg\vcpkg-master\installed\x64-windows\include" -L "D:\vcpkg\vcpkg-master\installed\x64-windows\lib" glfw3dll.lib opengl32.lib user32.lib gdi32.lib shell32.lib
if errorlevel 1 goto :error

copy /Y "D:\vcpkg\vcpkg-master\installed\x64-windows\bin\glfw3.dll" "." >nul
if errorlevel 1 goto :error

echo Build successful: particleMapImageGenerator.exe
pause
exit /b 0

:error
echo Build failed. Check the messages above.
pause
exit /b 1
