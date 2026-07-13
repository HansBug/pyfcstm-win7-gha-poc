@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "RUN_DIRECTORY=%SystemDrive%\pyfcstm-win7-poc"
set "RESULT_DRIVE="
set "STATUS=FAIL"
set "FAILURE=unknown"

ping 127.0.0.1 -n 10 >nul
for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    vol %%D: 2>nul | findstr /I /C:"PYFCSTMRES" >nul
    if not errorlevel 1 set "RESULT_DRIVE=%%D:"
)
if not defined RESULT_DRIVE goto :shutdown
> "%RUN_DIRECTORY%\gui-task-started.txt" echo started
> "%RESULT_DRIVE%\gui-task-started.txt" echo started

set /a WAIT_COUNT=0
:wait_for_system_stage
if exist "%RUN_DIRECTORY%\system-stage.txt" goto :system_stage_ready
if %WAIT_COUNT% GEQ 300 (
    set "FAILURE=system stage did not become ready"
    goto :finish
)
ping 127.0.0.1 -n 3 >nul
set /a WAIT_COUNT+=1
goto :wait_for_system_stage

:system_stage_ready
findstr /X /C:"PASS" "%RUN_DIRECTORY%\system-stage.txt" >nul
if errorlevel 1 (
    set "FAILURE=system stage did not pass"
    goto :finish
)

set "QT_QPA_PLATFORM=windows"
set "JAVA_HOME=%RUN_DIRECTORY%\java-runtime"
set "PATH=%JAVA_HOME%\bin;%RUN_DIRECTORY%;%PATH%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RUN_DIRECTORY%\run-gui-acceptance.ps1" "%RUN_DIRECTORY%" > "%RUN_DIRECTORY%\run-gui-acceptance.log" 2>&1
if errorlevel 1 (
    set "FAILURE=interactive fcstm-gui acceptance failed"
    goto :finish
)

if not exist "%RUN_DIRECTORY%\fcstm-gui-acceptance.json" (
    set "FAILURE=interactive acceptance JSON is missing"
    goto :finish
)
findstr /C:"\"status\": \"passed\"" "%RUN_DIRECTORY%\fcstm-gui-acceptance.json" >nul
if errorlevel 1 (
    set "FAILURE=interactive acceptance JSON was not passed"
    goto :finish
)
findstr /C:"\"passed\": 140" "%RUN_DIRECTORY%\fcstm-gui-acceptance.json" >nul
if errorlevel 1 (
    set "FAILURE=interactive acceptance JSON did not contain 140 passed checks"
    goto :finish
)
if not exist "%RUN_DIRECTORY%\desktop-before.png" (
    set "FAILURE=desktop-before.png is missing"
    goto :finish
)
if not exist "%RUN_DIRECTORY%\desktop-gui-visible.png" (
    set "FAILURE=desktop-gui-visible.png is missing"
    goto :finish
)
if not exist "%RUN_DIRECTORY%\desktop-after.png" (
    set "FAILURE=desktop-after.png is missing"
    goto :finish
)
if not exist "%RUN_DIRECTORY%\gui-session.txt" (
    set "FAILURE=gui-session.txt is missing"
    goto :finish
)

set "STATUS=PASS"
set "FAILURE="

:finish
> "%RESULT_DRIVE%\result.txt" echo %STATUS%
> "%RESULT_DRIVE%\failure.txt" echo %FAILURE%
> "%RESULT_DRIVE%\gui-stage.txt" echo %STATUS%
xcopy /E /I /H /Y "%RUN_DIRECTORY%\fcstm-gui-acceptance-artifacts" "%RESULT_DRIVE%\fcstm-gui-acceptance-artifacts" >nul 2>&1
if exist "%RUN_DIRECTORY%\fcstm-gui-acceptance.json" copy /Y "%RUN_DIRECTORY%\fcstm-gui-acceptance.json" "%RESULT_DRIVE%\fcstm-gui-acceptance.json" >nul 2>&1
if exist "%RUN_DIRECTORY%\fcstm-gui-acceptance.stdout.log" copy /Y "%RUN_DIRECTORY%\fcstm-gui-acceptance.stdout.log" "%RESULT_DRIVE%\fcstm-gui-acceptance.stdout.log" >nul 2>&1
if exist "%RUN_DIRECTORY%\fcstm-gui-acceptance.stderr.log" copy /Y "%RUN_DIRECTORY%\fcstm-gui-acceptance.stderr.log" "%RESULT_DRIVE%\fcstm-gui-acceptance.stderr.log" >nul 2>&1
if exist "%RUN_DIRECTORY%\run-gui-acceptance.log" copy /Y "%RUN_DIRECTORY%\run-gui-acceptance.log" "%RESULT_DRIVE%\run-gui-acceptance.log" >nul 2>&1
if exist "%RUN_DIRECTORY%\gui-session.txt" copy /Y "%RUN_DIRECTORY%\gui-session.txt" "%RESULT_DRIVE%\gui-session.txt" >nul 2>&1
if exist "%RUN_DIRECTORY%\desktop-before.png" copy /Y "%RUN_DIRECTORY%\desktop-before.png" "%RESULT_DRIVE%\desktop-before.png" >nul 2>&1
if exist "%RUN_DIRECTORY%\desktop-before.txt" copy /Y "%RUN_DIRECTORY%\desktop-before.txt" "%RESULT_DRIVE%\desktop-before.txt" >nul 2>&1
if exist "%RUN_DIRECTORY%\desktop-gui-visible.png" copy /Y "%RUN_DIRECTORY%\desktop-gui-visible.png" "%RESULT_DRIVE%\desktop-gui-visible.png" >nul 2>&1
if exist "%RUN_DIRECTORY%\desktop-gui-visible.txt" copy /Y "%RUN_DIRECTORY%\desktop-gui-visible.txt" "%RESULT_DRIVE%\desktop-gui-visible.txt" >nul 2>&1
if exist "%RUN_DIRECTORY%\desktop-after.png" copy /Y "%RUN_DIRECTORY%\desktop-after.png" "%RESULT_DRIVE%\desktop-after.png" >nul 2>&1
if exist "%RUN_DIRECTORY%\desktop-after.txt" copy /Y "%RUN_DIRECTORY%\desktop-after.txt" "%RESULT_DRIVE%\desktop-after.txt" >nul 2>&1
if exist "%RUN_DIRECTORY%\fcstm-gui-self-check.log" copy /Y "%RUN_DIRECTORY%\fcstm-gui-self-check.log" "%RESULT_DRIVE%\fcstm-gui-self-check.log" >nul 2>&1
if exist "%RUN_DIRECTORY%\fcstm-gui-self-check.json" copy /Y "%RUN_DIRECTORY%\fcstm-gui-self-check.json" "%RESULT_DRIVE%\fcstm-gui-self-check.json" >nul 2>&1
certutil -hashfile "%RUN_DIRECTORY%\pyfcstm.exe" SHA256 > "%RESULT_DRIVE%\hash.txt" 2>&1
certutil -hashfile "%RUN_DIRECTORY%\fcstm-gui.exe" SHA256 > "%RESULT_DRIVE%\fcstm-gui-hash.txt" 2>&1
> "%RESULT_DRIVE%\os.txt" (
    wmic os get Caption /value
    wmic os get Version /value
    wmic os get BuildNumber /value
    wmic os get ServicePackMajorVersion /value
    wmic os get ProductType /value
    wmic os get OSArchitecture /value
)
if exist "%RUN_DIRECTORY%\gui-task-started.txt" copy /Y "%RUN_DIRECTORY%\gui-task-started.txt" "%RESULT_DRIVE%\gui-task-started.txt" >nul 2>&1
schtasks /delete /tn PyfcstmWin7Gui /f >nul 2>&1
shutdown /s /t 0 /f
exit /b 0

:shutdown
shutdown /s /t 0 /f
exit /b 0
