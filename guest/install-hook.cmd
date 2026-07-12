@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "PAYLOAD_DRIVE="
for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\run-ci.cmd" set "PAYLOAD_DRIVE=%%D:"
)

if not defined PAYLOAD_DRIVE exit /b 1
mkdir "%WINDIR%\Setup\Scripts" >nul 2>&1
copy /Y "%PAYLOAD_DRIVE%\run-ci.cmd" "%WINDIR%\Setup\Scripts\SetupComplete.cmd" >nul
if errorlevel 1 exit /b 2

exit /b 0
