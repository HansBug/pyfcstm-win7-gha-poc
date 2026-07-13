@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "RUN_DIRECTORY=%SystemDrive%\pyfcstm-win7-poc"
set "PAYLOAD_DRIVE="
set "RESULT_DRIVE="
set "STATUS=FAIL"
set "FAILURE=unknown"
set "GUI_TASK=PyfcstmWin7Gui"
set "RESUME_TASK=PyfcstmWin7PocResume"

mkdir "%RUN_DIRECTORY%" >nul 2>&1
for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\verify-cli.cmd" set "PAYLOAD_DRIVE=%%D:"
)

ping 127.0.0.1 -n 6 >nul
set "DISKPART_SCRIPT=%TEMP%\pyfcstm-result-diskpart.txt"
> "%DISKPART_SCRIPT%" (
    echo select disk 1
    echo select partition 1
    echo assign letter=R
)
diskpart /s "%DISKPART_SCRIPT%" >nul 2>&1
del "%DISKPART_SCRIPT%" >nul 2>&1
if exist R:\ set "RESULT_DRIVE=R:"
if not defined RESULT_DRIVE (
    for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
        vol %%D: 2>nul | findstr /I /C:"PYFCSTMRES" >nul
        if not errorlevel 1 set "RESULT_DRIVE=%%D:"
    )
)
if not defined RESULT_DRIVE (
    for /f "tokens=2 delims==" %%D in ('wmic logicaldisk where "VolumeName='PYFCSTMRES'" get DeviceID /value ^| find "="') do set "RESULT_DRIVE=%%D"
)

if not exist "%RESULT_DRIVE%\" set "RESULT_DRIVE="
if not defined RESULT_DRIVE goto :shutdown
> "%RESULT_DRIVE%\run-ci-started.txt" echo started
if not defined PAYLOAD_DRIVE (
    set "FAILURE=bootstrap payload CD was not found"
    goto :finish
)

copy /Y "%PAYLOAD_DRIVE%\run-gui-ci.cmd" "%RUN_DIRECTORY%\run-gui-ci.cmd" >nul
copy /Y "%PAYLOAD_DRIVE%\run-gui-acceptance.ps1" "%RUN_DIRECTORY%\run-gui-acceptance.ps1" >nul
copy /Y "%PAYLOAD_DRIVE%\capture-desktop.ps1" "%RUN_DIRECTORY%\capture-desktop.ps1" >nul
if not exist "%RUN_DIRECTORY%\run-gui-ci.cmd" (
    set "FAILURE=interactive GUI runner copy failed"
    goto :finish
)
if not exist "%RUN_DIRECTORY%\run-gui-acceptance.ps1" (
    set "FAILURE=interactive GUI PowerShell runner copy failed"
    goto :finish
)
if not exist "%RUN_DIRECTORY%\capture-desktop.ps1" (
    set "FAILURE=desktop capture script copy failed"
    goto :finish
)

schtasks /delete /tn %GUI_TASK% /f >nul 2>&1
schtasks /create /tn %GUI_TASK% /tr "cmd.exe /c call %RUN_DIRECTORY%\run-gui-ci.cmd" /sc onlogon /ru ci /rp win7-poc-ephemeral /it /rl LIMITED /f > "%RUN_DIRECTORY%\gui-task-create.log" 2>&1
if errorlevel 1 (
    set "FAILURE=interactive GUI task registration failed"
    goto :finish
)

if not exist "%RUN_DIRECTORY%\ucrt-installed.txt" (
    if not exist "%PAYLOAD_DRIVE%\win7-ucrt.cab" (
        set "FAILURE=Windows 7 UCRT update was not found"
        goto :finish
    )
    > "%RUN_DIRECTORY%\ucrt-install.log" echo Installing the Windows 7 UCRT CAB with the Win7 servicing stack.
    dism.exe /online /add-package /packagepath:"%PAYLOAD_DRIVE%\win7-ucrt.cab" /quiet /norestart >> "%RUN_DIRECTORY%\ucrt-install.log" 2>&1
    if errorlevel 3010 goto :schedule-ucrt-reboot
    if errorlevel 1 (
        set "FAILURE=Windows 7 UCRT update failed"
        goto :finish
    )
    > "%RUN_DIRECTORY%\ucrt-installed.txt" echo installed
)

copy /Y "%PAYLOAD_DRIVE%\pyfcstm.exe" "%RUN_DIRECTORY%\pyfcstm.exe" >nul
copy /Y "%PAYLOAD_DRIVE%\fcstm-gui.exe" "%RUN_DIRECTORY%\fcstm-gui.exe" >nul
copy /Y "%PAYLOAD_DRIVE%\smt-verify.fcstm" "%RUN_DIRECTORY%\smt-verify.fcstm" >nul
copy /Y "%PAYLOAD_DRIVE%\vcruntime140_1.dll" "%RUN_DIRECTORY%\vcruntime140_1.dll" >nul
copy /Y "%PAYLOAD_DRIVE%\build-metadata.txt" "%RUN_DIRECTORY%\build-metadata.txt" >nul
copy /Y "%PAYLOAD_DRIVE%\fcstm-gui-build-metadata.txt" "%RUN_DIRECTORY%\fcstm-gui-build-metadata.txt" >nul
xcopy /E /I /H /Y "%PAYLOAD_DRIVE%\java-runtime" "%RUN_DIRECTORY%\java-runtime" >nul
if not exist "%RUN_DIRECTORY%\pyfcstm.exe" (
    set "FAILURE=executable copy failed"
    goto :finish
)
if not exist "%RUN_DIRECTORY%\fcstm-gui.exe" (
    set "FAILURE=fcstm-gui executable copy failed"
    goto :finish
)
if not exist "%RUN_DIRECTORY%\java-runtime\bin\java.exe" (
    set "FAILURE=portable Java runtime copy failed"
    goto :finish
)

call "%PAYLOAD_DRIVE%\verify-cli.cmd" "%RUN_DIRECTORY%" > "%RUN_DIRECTORY%\pyfcstm-verify.log" 2>&1
if errorlevel 1 (
    set "FAILURE=pyfcstm verify-cli.cmd returned a nonzero status"
    goto :finish
)
call "%PAYLOAD_DRIVE%\verify-gui.cmd" "%RUN_DIRECTORY%" > "%RUN_DIRECTORY%\fcstm-gui-self-check.log" 2>&1
if errorlevel 1 (
    set "FAILURE=fcstm-gui verify-gui.cmd returned a nonzero status"
    goto :finish
)
set "STATUS=PASS"
set "FAILURE="

> "%RUN_DIRECTORY%\system-stage.txt" echo PASS
> "%RESULT_DRIVE%\system-stage.txt" echo PASS
> "%RESULT_DRIVE%\result.txt" echo RUNNING
> "%RESULT_DRIVE%\failure.txt" echo interactive GUI stage pending
copy /Y "%RUN_DIRECTORY%\gui-task-create.log" "%RESULT_DRIVE%\gui-task-create.log" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\pyfcstm-verify.log" "%RESULT_DRIVE%\pyfcstm-verify.log" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\pyfcstm-self-check.txt" "%RESULT_DRIVE%\pyfcstm-self-check.txt" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\pyfcstm-self-check-commands.log" "%RESULT_DRIVE%\pyfcstm-self-check-commands.log" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\fcstm-gui-self-check.log" "%RESULT_DRIVE%\fcstm-gui-self-check.log" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\fcstm-gui-self-check.json" "%RESULT_DRIVE%\fcstm-gui-self-check.json" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\java-version-guest.txt" "%RESULT_DRIVE%\java-version-guest.txt" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\build-metadata.txt" "%RESULT_DRIVE%\build-metadata.txt" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\fcstm-gui-build-metadata.txt" "%RESULT_DRIVE%\fcstm-gui-build-metadata.txt" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\ucrt-install.log" "%RESULT_DRIVE%\ucrt-install.log" >nul 2>&1
exit /b 0

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
certutil -hashfile "%RUN_DIRECTORY%\fcstm-gui.exe" SHA256 > "%RESULT_DRIVE%\fcstm-gui-hash.txt" 2>&1
copy /Y "%RUN_DIRECTORY%\pyfcstm-verify.log" "%RESULT_DRIVE%\pyfcstm-verify.log" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\pyfcstm-self-check.txt" "%RESULT_DRIVE%\pyfcstm-self-check.txt" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\pyfcstm-self-check-commands.log" "%RESULT_DRIVE%\pyfcstm-self-check-commands.log" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\fcstm-gui-self-check.log" "%RESULT_DRIVE%\fcstm-gui-self-check.log" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\fcstm-gui-self-check.json" "%RESULT_DRIVE%\fcstm-gui-self-check.json" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\java-version-guest.txt" "%RESULT_DRIVE%\java-version-guest.txt" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\build-metadata.txt" "%RESULT_DRIVE%\build-metadata.txt" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\fcstm-gui-build-metadata.txt" "%RESULT_DRIVE%\fcstm-gui-build-metadata.txt" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\ucrt-install.log" "%RESULT_DRIVE%\ucrt-install.log" >nul 2>&1
copy /Y "%RUN_DIRECTORY%\gui-task-create.log" "%RESULT_DRIVE%\gui-task-create.log" >nul 2>&1
schtasks /delete /tn %GUI_TASK% /f >nul 2>&1
schtasks /delete /tn %RESUME_TASK% /f >nul 2>&1

:shutdown
shutdown /s /t 0 /f
exit /b 0

:schedule-ucrt-reboot
copy /Y "%PAYLOAD_DRIVE%\run-ci.cmd" "%WINDIR%\Setup\Scripts\run-ci-resume.cmd" >nul
schtasks /create /tn %RESUME_TASK% /tr "cmd.exe /c call %WINDIR%\Setup\Scripts\run-ci-resume.cmd" /sc onlogon /ru SYSTEM /rl HIGHEST /f >nul
shutdown /r /t 0 /f
exit /b 0
