@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "RUN_DIRECTORY=%SystemDrive%\pyfcstm-win7-poc"
set "PAYLOAD_DRIVE="
set "RESULT_DRIVE=D:"
set "STATUS=FAIL"
set "FAILURE=unknown"

mkdir "%RUN_DIRECTORY%" >nul 2>&1
for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\verify-cli.cmd" set "PAYLOAD_DRIVE=%%D:"
)

ping 127.0.0.1 -n 6 >nul
for /f "tokens=2 delims==" %%D in ('wmic logicaldisk where "VolumeName='PYFCSTMRES'" get DeviceID /value ^| find "="') do set "RESULT_DRIVE=%%D"

if not exist "%RESULT_DRIVE%\" set "RESULT_DRIVE="
if not defined RESULT_DRIVE goto :shutdown
> "%RESULT_DRIVE%\run-ci-started.txt" echo started
if not defined PAYLOAD_DRIVE (
    set "FAILURE=bootstrap payload CD was not found"
    goto :finish
)

copy /Y "%PAYLOAD_DRIVE%\pyfcstm.exe" "%RUN_DIRECTORY%\pyfcstm.exe" >nul
copy /Y "%PAYLOAD_DRIVE%\smt-verify.fcstm" "%RUN_DIRECTORY%\smt-verify.fcstm" >nul
if not exist "%RUN_DIRECTORY%\pyfcstm.exe" (
    set "FAILURE=executable copy failed"
    goto :finish
)

call "%PAYLOAD_DRIVE%\verify-cli.cmd" "%RUN_DIRECTORY%" > "%RUN_DIRECTORY%\verify-cli.log" 2>&1
if errorlevel 1 (
    set "FAILURE=verify-cli.cmd returned a nonzero status"
    goto :finish
)
set "STATUS=PASS"
set "FAILURE="

:finish
> "%RESULT_DRIVE%\result.txt" echo %STATUS%
> "%RESULT_DRIVE%\failure.txt" echo %FAILURE%
> "%RESULT_DRIVE%\os.txt" (
    wmic os get Caption /value
    wmic os get Version /value
    wmic os get BuildNumber /value
    wmic os get ServicePackMajorVersion /value
    wmic os get ProductType /value
    wmic os get OSArchitecture /value
)
certutil -hashfile "%RUN_DIRECTORY%\pyfcstm.exe" SHA256 > "%RESULT_DRIVE%\hash.txt" 2>&1
copy /Y "%RUN_DIRECTORY%\verify-cli.log" "%RESULT_DRIVE%\verify-cli.log" >nul 2>&1

:shutdown
shutdown /s /t 0 /f
exit /b 0
