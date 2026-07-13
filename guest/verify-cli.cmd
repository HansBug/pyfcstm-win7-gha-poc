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
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] version
    >> "%REPORT%" echo [!TOTAL!] OK version
) else (
    set /a FAILED+=1
    echo [FAIL] version
    >> "%REPORT%" echo [!TOTAL!] FAIL version
)

rem 2. Help and command inventory
"%CLI%" -h > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
for %%T in ("Usage:" "plantuml" "generate" "simulate") do (
    findstr /I /C:%%~T "%OUTPUT%" >nul
    if errorlevel 1 set "OK=0"
)
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] help
    >> "%REPORT%" echo [!TOTAL!] OK help
) else (
    set /a FAILED+=1
    echo [FAIL] help
    >> "%REPORT%" echo [!TOTAL!] FAIL help
)

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
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] plantuml generation
    >> "%REPORT%" echo [!TOTAL!] OK plantuml generation
) else (
    set /a FAILED+=1
    echo [FAIL] plantuml generation
    >> "%REPORT%" echo [!TOTAL!] FAIL plantuml generation
)

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
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] JSON inspect
    >> "%REPORT%" echo [!TOTAL!] OK JSON inspect
) else (
    set /a FAILED+=1
    echo [FAIL] JSON inspect
    >> "%REPORT%" echo [!TOTAL!] FAIL JSON inspect
)

rem 5. Built-in Python template generation
rmdir /s /q "%GENERATED_DIRECTORY%" >nul 2>&1
"%CLI%" generate -i "%MODEL%" --template python -o "%GENERATED_DIRECTORY%" --clear > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
if not exist "%GENERATED_DIRECTORY%\machine.py" set "OK=0"
if not exist "%GENERATED_DIRECTORY%\README.md" set "OK=0"
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] built-in python template
    >> "%REPORT%" echo [!TOTAL!] OK built-in python template
) else (
    set /a FAILED+=1
    echo [FAIL] built-in python template
    >> "%REPORT%" echo [!TOTAL!] FAIL built-in python template
)

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
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] simulate help
    >> "%REPORT%" echo [!TOTAL!] OK simulate help
) else (
    set /a FAILED+=1
    echo [FAIL] simulate help
    >> "%REPORT%" echo [!TOTAL!] FAIL simulate help
)

rem 7. Simulator current state
"%CLI%" simulate -i "%MODEL%" -e current --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
findstr /I /C:"State:" "%OUTPUT%" >nul
if errorlevel 1 findstr /I /C:"state" "%OUTPUT%" >nul
if errorlevel 1 set "OK=0"
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] simulate current
    >> "%REPORT%" echo [!TOTAL!] OK simulate current
) else (
    set /a FAILED+=1
    echo [FAIL] simulate current
    >> "%REPORT%" echo [!TOTAL!] FAIL simulate current
)

rem 8. Simulator cycle
"%CLI%" simulate -i "%MODEL%" -e "cycle; current" --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
findstr /I /C:"Cycle" "%OUTPUT%" >nul
if errorlevel 1 findstr /I /C:"cycle" "%OUTPUT%" >nul
if errorlevel 1 set "OK=0"
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] simulate cycle
    >> "%REPORT%" echo [!TOTAL!] OK simulate cycle
) else (
    set /a FAILED+=1
    echo [FAIL] simulate cycle
    >> "%REPORT%" echo [!TOTAL!] FAIL simulate cycle
)

rem 9. Multiple simulator commands
"%CLI%" simulate -i "%MODEL%" -e "current; cycle; current; events" --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] simulate multiple commands
    >> "%REPORT%" echo [!TOTAL!] OK simulate multiple commands
) else (
    set /a FAILED+=1
    echo [FAIL] simulate multiple commands
    >> "%REPORT%" echo [!TOTAL!] FAIL simulate multiple commands
)

rem 10. Simulator history
"%CLI%" simulate -i "%MODEL%" -e "cycle; cycle; history" --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
findstr /I /C:"Cycle" "%OUTPUT%" >nul
if errorlevel 1 findstr /I /C:"cycle" "%OUTPUT%" >nul
if errorlevel 1 set "OK=0"
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] simulate history
    >> "%REPORT%" echo [!TOTAL!] OK simulate history
) else (
    set /a FAILED+=1
    echo [FAIL] simulate history
    >> "%REPORT%" echo [!TOTAL!] FAIL simulate history
)

rem 11. Simulator settings
"%CLI%" simulate -i "%MODEL%" -e "setting; setting color off; setting" --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] simulate settings
    >> "%REPORT%" echo [!TOTAL!] OK simulate settings
) else (
    set /a FAILED+=1
    echo [FAIL] simulate settings
    >> "%REPORT%" echo [!TOTAL!] FAIL simulate settings
)

rem 12. Simulator clear/reset
"%CLI%" simulate -i "%MODEL%" -e "cycle; clear; current" --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] simulate clear
    >> "%REPORT%" echo [!TOTAL!] OK simulate clear
) else (
    set /a FAILED+=1
    echo [FAIL] simulate clear
    >> "%REPORT%" echo [!TOTAL!] FAIL simulate clear
)

rem 13. Simulator no-color mode
"%CLI%" simulate -i "%MODEL%" -e current --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if not "!RC!"=="0" set "OK=0"
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] simulate no-color
    >> "%REPORT%" echo [!TOTAL!] OK simulate no-color
) else (
    set /a FAILED+=1
    echo [FAIL] simulate no-color
    >> "%REPORT%" echo [!TOTAL!] FAIL simulate no-color
)

rem 14. Invalid input file must fail
"%CLI%" plantuml -i "%RUN_DIRECTORY%\missing.fcstm" -o "%RUN_DIRECTORY%\missing.puml" > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if "!RC!"=="0" set "OK=0"
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] invalid input file
    >> "%REPORT%" echo [!TOTAL!] OK invalid input file
) else (
    set /a FAILED+=1
    echo [FAIL] invalid input file
    >> "%REPORT%" echo [!TOTAL!] FAIL invalid input file
)

rem 15. Invalid simulator command must fail or report an error
"%CLI%" simulate -i "%MODEL%" -e invalid_command_xyz --no-color > "%OUTPUT%" 2>&1
set "RC=!ERRORLEVEL!"
type "%OUTPUT%" >> "%LOG%"
set "OK=1"
if "!RC!"=="0" (
    findstr /I /C:"Unknown command" /C:"unknown" "%OUTPUT%" >nul
    if errorlevel 1 set "OK=0"
)
set /a TOTAL+=1
if !OK! EQU 1 (
    set /a PASSED+=1
    echo [OK] invalid simulate command
    >> "%REPORT%" echo [!TOTAL!] OK invalid simulate command
) else (
    set /a FAILED+=1
    echo [FAIL] invalid simulate command
    >> "%REPORT%" echo [!TOTAL!] FAIL invalid simulate command
)

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
