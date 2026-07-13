@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "RUN_DIRECTORY=%~1"
set "GUI=%RUN_DIRECTORY%\fcstm-gui.exe"
set "REPORT=%RUN_DIRECTORY%\fcstm-gui-self-check.json"
set "JAVA_HOME=%RUN_DIRECTORY%\java-runtime"
set "PATH=%JAVA_HOME%\bin;%RUN_DIRECTORY%;%PATH%"
set "QT_QPA_PLATFORM=offscreen"

if not exist "%GUI%" exit /b 30
if not exist "%JAVA_HOME%\bin\java.exe" exit /b 31

java.exe -version > "%RUN_DIRECTORY%\java-version-guest.txt" 2>&1
if errorlevel 1 exit /b 32

"%GUI%" --self-check --json-report "%REPORT%"
if errorlevel 1 exit /b 33
if not exist "%REPORT%" exit /b 34
findstr /c:"\"status\": \"passed\"" "%REPORT%" >nul
if errorlevel 1 exit /b 35
findstr /c:"\"passed\": 182" "%REPORT%" >nul
if errorlevel 1 exit /b 36

exit /b 0
