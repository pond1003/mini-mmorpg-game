@echo off
rem Publish a patch: Release.bat 1.0.1 "what changed"
rem Sets the game version, builds via Export.bat, writes manifest.json (engine + sha256 of exe/pck) and
rem creates a GitHub Release with pck + exe + manifest + zip (needs gh CLI, else prints manual steps)
setlocal
set VER=%~1
set NOTES=%~2
if "%VER%"=="" (echo Usage: Release.bat ^<version e.g. 1.0.1^> "release notes" & exit /b 1)
if "%NOTES%"=="" set NOTES=Patch v%VER%
set OUT=%~dp0export\ShadowNinja
set REL=%~dp0export\release
set GODOT=%~dp0tools\godot\Godot_v4.7.2-stable_win64_console.exe
powershell -NoProfile -Command "$p='%~dp0shadow_ninja_godot\project.godot'; $q=[char]34; $s=[IO.File]::ReadAllText($p); $n=$s -replace ('config/version='+$q+'[^'+$q+']*'+$q), ('config/version='+$q+'%VER%'+$q); if ($n -notmatch ('config/version='+$q+'%VER%'+$q)) { exit 1 }; [IO.File]::WriteAllText($p,$n)"
if errorlevel 1 (echo Could not set version in project.godot & exit /b 1)
call "%~dp0Export.bat"
if errorlevel 1 exit /b 1
if exist "%REL%" rmdir /s /q "%REL%"
mkdir "%REL%"
copy /y "%OUT%\ShadowNinja.pck" "%REL%\" >nul
copy /y "%OUT%\ShadowNinja.exe" "%REL%\" >nul
copy /y "%~dp0export\ShadowNinja_win64.zip" "%REL%\" >nul
rem engine = first 4 parts of "godot --version" (e.g. 4.7.2.stable), the same string the game reports
powershell -NoProfile -Command "$e=((& '%GODOT%' --version | Select-Object -Last 1).Trim().Split('.')[0..3] -join '.'); $h={param($f) (Get-FileHash $f -Algorithm SHA256).Hash.ToLower()}; $m=[ordered]@{version='%VER%'; engine=$e; pck_sha256=(& $h '%REL%\ShadowNinja.pck'); exe_sha256=(& $h '%REL%\ShadowNinja.exe')}; [IO.File]::WriteAllText('%REL%\manifest.json', ($m | ConvertTo-Json)); Get-Content '%REL%\manifest.json'"
if errorlevel 1 (echo Could not write manifest.json & exit /b 1)
where gh >nul 2>nul
if errorlevel 1 goto manual
gh release create v%VER% "%REL%\ShadowNinja.pck" "%REL%\ShadowNinja.exe" "%REL%\manifest.json" "%REL%\ShadowNinja_win64.zip" --title "v%VER%" --notes "%NOTES%"
if errorlevel 1 (echo gh release failed & exit /b 1)
echo Released v%VER%. Remember to commit the version bump in project.godot.
exit /b 0
:manual
echo gh CLI not found. Create the release by hand:
echo   1. Open https://github.com/pond1003/mini-mmorpg-game/releases/new
echo   2. Tag: v%VER%   Notes: %NOTES%
echo   3. Attach all 4 files in export\release\ (ShadowNinja.pck, ShadowNinja.exe, manifest.json, ShadowNinja_win64.zip)
echo Then commit the version bump in project.godot.
