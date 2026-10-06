@echo off
rem Build the Windows release into export\ShadowNinja\ (ShadowNinja.exe + ShadowNinja.pck) and zip it
setlocal
set GODOT=%~dp0tools\godot\Godot_v4.7.2-stable_win64_console.exe
set OUT=%~dp0export\ShadowNinja
if not exist "%GODOT%" (echo Godot not found: %GODOT% & exit /b 1)
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%"
"%GODOT%" --headless --path "%~dp0shadow_ninja_godot" --export-release "Windows Desktop" "%OUT%\ShadowNinja.exe"
if errorlevel 1 (echo Export failed & exit /b 1)
if not exist "%OUT%\ShadowNinja.pck" (echo Export failed: no .pck produced & exit /b 1)
powershell -NoProfile -Command "Compress-Archive -Force -Path '%OUT%\*' -DestinationPath '%~dp0export\ShadowNinja_win64.zip'"
if errorlevel 1 (echo Zip failed & exit /b 1)
echo Done: export\ShadowNinja_win64.zip
