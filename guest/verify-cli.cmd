@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "RUN_DIRECTORY=%~1"
set "CLI=%RUN_DIRECTORY%\pyfcstm.exe"
set "MODEL=%RUN_DIRECTORY%\smt-verify.fcstm"
set "PLANTUML_OUTPUT=%RUN_DIRECTORY%\smt-verify.puml"
set "INSPECT_OUTPUT=%RUN_DIRECTORY%\inspect.json"
set "GENERATED_DIRECTORY=%RUN_DIRECTORY%\generated-python"
set "REPORT=%RUN_DIRECTORY%\pyfcstm-self-check.txt"
set "OUTPUT=%RUN_DIRECTORY%\pyfcstm-self-check-output.txt"
set "LOG=%RUN_DIRECTORY%\pyfcstm-self-check-commands.log"
set /a TOTAL=0, PASSED=0, FAILED=0

if not exist "%CLI%" exit /b 10
if not exist "%MODEL%" exit /b 11

> "%REPORT%" echo schema=pyfcstm.cli-self-check
>> "%REPORT%" echo contract=Windows 7 guest CLI behavior
>> "%REPORT%" echo.
> "%LOG%" echo pyfcstm CLI self-check command output

rem 1. Version
"%CLI%" -v > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
findstr /I /C:"Pyfcstm" "%OUTPUT%" >nul
if errorlevel 1 set "OK=0"
if !OK! EQU 0 (call :record "version" 1) else (call :record "version" 0)

rem 2. Help and command inventory
"%CLI%" -h > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
findstr /I /C:"Usage:" "%OUTPUT%" >nul
if errorlevel 1 set "OK=0"
findstr /I /C:"plantuml" "%OUTPUT%" >nul
if errorlevel 1 set "OK=0"
findstr /I /C:"generate" "%OUTPUT%" >nul
if errorlevel 1 set "OK=0"
findstr /I /C:"simulate" "%OUTPUT%" >nul
if errorlevel 1 set "OK=0"
if !OK! EQU 0 (call :record "help" 1) else (call :record "help" 0)

rem 3. PlantUML generation and delimiters
del /q "%PLANTUML_OUTPUT%" >nul 2>&1
"%CLI%" plantuml -i "%MODEL%" -o "%PLANTUML_OUTPUT%" > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
if not exist "%PLANTUML_OUTPUT%" set "OK=0"
findstr /C:"@startuml" "%PLANTUML_OUTPUT%" >nul
if errorlevel 1 set "OK=0"
findstr /C:"@enduml" "%PLANTUML_OUTPUT%" >nul
if errorlevel 1 set "OK=0"
if !OK! EQU 0 (call :record "plantuml generation" 1) else (call :record "plantuml generation" 0)

rem 4. JSON inspect
>> "%LOG%" echo [json inspect]
del /q "%INSPECT_OUTPUT%" >nul 2>&1
"%CLI%" inspect -i "%MODEL%" --format json --color never -o "%INSPECT_OUTPUT%" > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
if not exist "%INSPECT_OUTPUT%" set "OK=0"
findstr /I /C:"root_state_path" "%INSPECT_OUTPUT%" >nul
if errorlevel 1 set "OK=0"
if !OK! EQU 0 (call :record "JSON inspect" 1) else (call :record "JSON inspect" 0)

rem 5. Built-in Python template generation
rmdir /s /q "%GENERATED_DIRECTORY%" >nul 2>&1
"%CLI%" generate -i "%MODEL%" --template python -o "%GENERATED_DIRECTORY%" --clear > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
if not exist "%GENERATED_DIRECTORY%\machine.py" set "OK=0"
if not exist "%GENERATED_DIRECTORY%\README.md" set "OK=0"
if !OK! EQU 0 (call :record "built-in python template" 1) else (call :record "built-in python template" 0)

rem 6. Simulator help
>> "%LOG%" echo [simulate help]
"%CLI%" simulate -h > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
findstr /I /C:"Interactive state machine simulator" "%OUTPUT%" >nul
if errorlevel 1 set "OK=0"
findstr /I /C:"--no-color" "%OUTPUT%" >nul
if errorlevel 1 set "OK=0"
if !OK! EQU 0 (call :record "simulate help" 1) else (call :record "simulate help" 0)

rem 7. Simulator current state
"%CLI%" simulate -i "%MODEL%" -e current --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
findstr /I /C:"State:" "%OUTPUT%" >nul
if errorlevel 1 findstr /I /C:"state" "%OUTPUT%" >nul
if errorlevel 1 set "OK=0"
if !OK! EQU 0 (call :record "simulate current" 1) else (call :record "simulate current" 0)

rem 8. Simulator cycle
"%CLI%" simulate -i "%MODEL%" -e "cycle; current" --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
findstr /I /C:"Cycle" "%OUTPUT%" >nul
if errorlevel 1 findstr /I /C:"cycle" "%OUTPUT%" >nul
if errorlevel 1 set "OK=0"
if !OK! EQU 0 (call :record "simulate cycle" 1) else (call :record "simulate cycle" 0)

rem 9. Multiple simulator commands
"%CLI%" simulate -i "%MODEL%" -e "current; cycle; current; events" --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
if "!RC!"=="0" (call :record "simulate multiple commands" 0) else (call :record "simulate multiple commands" 1)

rem 10. Simulator history
"%CLI%" simulate -i "%MODEL%" -e "cycle; cycle; history" --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
findstr /I /C:"Cycle" "%OUTPUT%" >nul
if errorlevel 1 findstr /I /C:"cycle" "%OUTPUT%" >nul
if errorlevel 1 set "OK=0"
if !OK! EQU 0 (call :record "simulate history" 1) else (call :record "simulate history" 0)

rem 11. Simulator settings
"%CLI%" simulate -i "%MODEL%" -e "setting; setting color off; setting" --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
if "!RC!"=="0" (call :record "simulate settings" 0) else (call :record "simulate settings" 1)

rem 12. Simulator clear/reset
"%CLI%" simulate -i "%MODEL%" -e "cycle; clear; current" --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
if "!RC!"=="0" (call :record "simulate clear" 0) else (call :record "simulate clear" 1)

rem 13. Simulator no-color mode
"%CLI%" simulate -i "%MODEL%" -e current --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
if "!RC!"=="0" (call :record "simulate no-color" 0) else (call :record "simulate no-color" 1)

rem 14. Invalid input file must fail
"%CLI%" plantuml -i "%RUN_DIRECTORY%\missing.fcstm" -o "%RUN_DIRECTORY%\missing.puml" > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
if "!RC!"=="0" (call :record "invalid input file" 1) else (call :record "invalid input file" 0)

rem 15. Invalid simulator command must fail or report an error
"%CLI%" simulate -i "%MODEL%" -e invalid_command_xyz --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
if not "!RC!"=="0" (
    call :record "invalid simulate command" 0
) else (
    findstr /I /C:"Unknown command" /C:"unknown" "%OUTPUT%" >nul
    if errorlevel 1 (call :record "invalid simulate command" 1) else (call :record "invalid simulate command" 0)
)

:finish
>> "%REPORT%" echo.
>> "%REPORT%" echo total=!TOTAL!
>> "%REPORT%" echo passed=!PASSED!
>> "%REPORT%" echo failed=!FAILED!
if !FAILED! EQU 0 (
    >> "%REPORT%" echo status=passed
    echo pyfcstm CLI self-check: !PASSED!/!TOTAL! passed
    del /q "%OUTPUT%" >nul 2>&1
    del /q "%GENERATED_DIRECTORY%\machine.py" "%GENERATED_DIRECTORY%\README.md" >nul 2>&1
    rmdir /s /q "%GENERATED_DIRECTORY%" >nul 2>&1
    exit /b 0
)
>> "%REPORT%" echo status=failed
echo pyfcstm CLI self-check: !PASSED!/!TOTAL! passed, !FAILED! failed
exit /b 1

:record
set /a TOTAL+=1
if "%~2"=="0" (
    set /a PASSED+=1
    echo [OK] %~1
    >> "%REPORT%" echo [!TOTAL!] OK %~1
) else (
    set /a FAILED+=1
    echo [FAIL] %~1
    >> "%REPORT%" echo [!TOTAL!] FAIL %~1
)
exit /b 0
