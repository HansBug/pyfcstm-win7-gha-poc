@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "RUN_DIRECTORY=%~1"
set "CLI=%RUN_DIRECTORY%\pyfcstm.exe"
set "MODEL=%RUN_DIRECTORY%\smt-verify.fcstm"
set "PLANTUML_OUTPUT=%RUN_DIRECTORY%\smt-verify.puml"
set "INSPECT_OUTPUT=%RUN_DIRECTORY%\inspect.json"

if not exist "%CLI%" exit /b 10
if not exist "%MODEL%" exit /b 11

"%CLI%" -v
if errorlevel 1 exit /b 20
"%CLI%" -h
if errorlevel 1 exit /b 21
"%CLI%" plantuml -i "%MODEL%" -o "%PLANTUML_OUTPUT%"
if errorlevel 1 exit /b 22
if not exist "%PLANTUML_OUTPUT%" exit /b 23
"%CLI%" inspect -i "%MODEL%" --enable-verify --max-complexity-tier smt_linear --format json --color never -o "%INSPECT_OUTPUT%"
if errorlevel 1 exit /b 24
findstr /c:"smt_local" "%INSPECT_OUTPUT%" >nul
if errorlevel 1 exit /b 25

exit /b 0
