@echo off
setlocal enabledelayedexpansion

::
:: BATCH FILE TO SYNCHRONIZE TWO KEEPASS DATABASES USING KEEPASSXC-CLI.EXE
::
:: The purpose is so that you can use two different virtual drives to synchronize your KeePassXC database across different devices
:: and keep those two always in sync.
::
:: I store this as a windows batch file located in my documents directory and
:: then call it regularly using windows Task Scheduler
::
:: A Task Scheduler trigger sets the script to run once at day at a certain time
::  - Trigger is "On a schedule" "Daily" at a certain time. Then under "Advanced Settings" below, repeat task every "5 minutes" for a duration "1 day".
::  - Thus it starts once a day and then repeats every 5 minutes throughout the day.  The next day it restarts and runs every 5 minutes again
::  - If there are no changes to either file, the script simply exits.  Thus it can be run every 5 minutes, 10, 30 or whatever you like.
::
:: It saves a log file with records of updates, and which direction, as well as errors in Documents/KeePassAutomergeLogs
::
:: It could be set up to synchronize the database held in any two virtual drives - Microsoft, Dropbox, Google Drive, SeaDrive, NextCloud, etc etc
::
:: If it needs to update the "main" database, the one opened by KeePassXC GUI (and here, the Google Drive database), then it 
:: closes the KeePassXC GUI, then reopens it again afterwards, minimized to the try
:: To do that (or any of the other merges etc) below, you will need a password-protect database - keyfiles might be possible by altering the respective keepassxc-cli.exe lines below
:: When opening the KeePassXC GUI minimized to the tray, it also opens the DB with the password (see below) because that is what I prefer.  You can edit below to change this behavior.
::
:: Password is saved as a variable below - there are other ways to do it that may be more secure, but that is the simplest.

:: --- CONFIGURATION ---
set "KP=C:\Program Files\KeePassXC\keepassxc.exe"
set "KP_CLI=C:\Program Files\KeePassXC\keepassxc-cli.exe"
set "DB_SEA=E:\Seadrive\My Libraries\KeePass\MyKeePass.kdbx"
set "DB_GDRIVE=E:\Google Drive\KeePass\MyHughKeePass.kdbx"
set "DB_PASSWORD=TOPSEKRITSTUFF"
:: Max logfile size in bytes
set "MAX_LOG_SIZE=1048576"

cd /d "%~dp0"

:: Folder to store sync state
:: Windows Documents dir for this user, a subdirectory named KeePassAutomergeLogs within that directory
set "STATE_DIR=%~dp0KeePassAutomergeLogs"

:: =========================================================

if not exist "%STATE_DIR%" mkdir "%STATE_DIR%"

set "SEA_HASH_FILE=%STATE_DIR%\sea.hash"
set "GDRIVE_HASH_FILE=%STATE_DIR%\gdrive.hash"
set "LOGFILE=%STATE_DIR%\keepass_sync.log"

:: --- Validate ---
if not exist "%KP%" goto :error
if not exist "%KP_CLI%" goto :error
if not exist "%DB_SEA%" goto :error
if not exist "%DB_GDRIVE%" goto :error



:: --- Get initial hashes ---
call :GetHash "%DB_SEA%" CUR_SEA_HASH
call :GetHash "%DB_GDRIVE%" CUR_GDRIVE_HASH

:: =========================================================
:: LOAD PREVIOUS HASHES
:: =========================================================

set "OLD_SEA_HASH="
set "OLD_GDRIVE_HASH="

if exist "%SEA_HASH_FILE%" (
    set /p OLD_SEA_HASH=<"%SEA_HASH_FILE%"
)

if exist "%GDRIVE_HASH_FILE%" (
    set /p OLD_GDRIVE_HASH=<"%GDRIVE_HASH_FILE%"
)

echo OLD SEAFILE HASH: %OLD_SEA_HASH%
echo OLD GOOGLEDRIVE HASH: %OLD_GDRIVE_HASH%

:: =========================================================
:: DETERMINE WHAT CHANGED
:: =========================================================

:: Remove spaces just in case
set "CUR_SEA_HASH=!CUR_SEA_HASH: =!"
set "OLD_SEA_HASH=!OLD_SEA_HASH: =!"

set "CUR_GDRIVE_HASH=!CUR_GDRIVE_HASH: =!"
set "OLD_GDRIVE_HASH=!OLD_GDRIVE_HASH: =!"

echo CURSEA: [!CUR_SEA_HASH!]
echo OLDSEA: [!OLD_SEA_HASH!]
echo CURGDRIVE: [!CUR_GDRIVE_HASH!]
echo OLDGDRIVE: [!OLD_GDRIVE_HASH!]

set "SEA_CHANGED=0"
set "GDRIVE_CHANGED=0"

if /i "!CUR_SEA_HASH!" neq "!OLD_SEA_HASH!" (
    set "SEA_CHANGED=1"
)

if /i "!CUR_GDRIVE_HASH!" neq "!OLD_GDRIVE_HASH!" (
    set "GDRIVE_CHANGED=1"
)

:: First run — initialize hashes and exit
if not defined OLD_SEA_HASH (
    echo First run - saving hashes
    goto :savehashes
)

:: Nothing changed
if "!SEA_CHANGED!"=="0" if "!GDRIVE_CHANGED!"=="0" (
    echo No database changes detected
    goto :end
)


:: --- Backups ---
copy /y "%DB_SEA%" "%DB_SEA%.bak" >nul
copy /y "%DB_GDRIVE%" "%DB_GDRIVE%.bak" >nul



:: =========================================================
:: SYNC LOGIC
:: =========================================================

:: BOTH changed -> bidirectional merge
if "!SEA_CHANGED!"=="1" if "!GDRIVE_CHANGED!"=="1" (

    echo Both databases changed - bidirectional merge
    call :log BOTH_DBS_CHANGED Merging bidirectionally SeaDrive and GoogleDrive
    
    REM Need to close GUI DB first as otherwise it is locked & no change allowed
    "%KP%" --lock 
    wmic process where name="keepassxc.exe" delete


    echo %DB_PASSWORD%| "%KP_CLI%" merge -s "%DB_SEA%" "%DB_GDRIVE%"
    if errorlevel 1 (
        echo ERROR merging Google Drive into Seadrive - restoring original databases
        echo %DB_PASSWORD%| start "" /B "%KP%" --minimized --pw-stdin "%DB_GDRIVE%"
        goto :restore
    )

    echo %DB_PASSWORD%| "%KP_CLI%" merge -s "%DB_GDRIVE%" "%DB_SEA%"
    if errorlevel 1 (
        echo ERROR merging SeaDrive into Google Drive - restoring original databases
        echo %DB_PASSWORD%| start "" /B "%KP%" --minimized --pw-stdin "%DB_GDRIVE%"
        goto :restore
    )
    
    echo %DB_PASSWORD%| start "" /B "%KP%" --minimized --pw-stdin "%DB_GDRIVE%"

    goto :savehashes
)

:: ONLY GDRIVE changed
if "!GDRIVE_CHANGED!"=="1" (

    echo Google Drive changed - syncing into SeaDrive
    call :log GDRIVE_CHANGED Merging GoogleDrive to SeaDrive

    echo %DB_PASSWORD%| "%KP_CLI%" merge -s "%DB_SEA%" "%DB_GDRIVE%"
    if errorlevel 1 goto :restore

    goto :savehashes
)

:: ONLY SEA changed
if "!SEA_CHANGED!"=="1" (

    echo SeaDrive changed - syncing into Google Drive
    call :log SEADRIVE_CHANGED Merging SeaDrive to GoogleDrive

    REM Need to close GUI DB first as otherwise it is locked & no change allowed
    "%KP%" --lock 
    wmic process where name="keepassxc.exe" delete
    
    echo %DB_PASSWORD%| "%KP_CLI%" merge -s "%DB_GDRIVE%" "%DB_SEA%"
    if errorlevel 1 (
        echo ERROR merging SeaDrive into Google Drive - restoring original databases
        echo %DB_PASSWORD%| start "" /B "%KP%" --minimized --pw-stdin "%DB_GDRIVE%"
        goto :restore
    )
    
    echo %DB_PASSWORD%| start "" /B "%KP%" --minimized --pw-stdin "%DB_GDRIVE%"

    goto :savehashes
)

goto :end

:: =========================================================
:: SAVE NEW HASHES && GENERAL CLEANUP
:: =========================================================

:savehashes

call :GetHash "%DB_SEA%" CUR_SEA_HASH
call :GetHash "%DB_GDRIVE%" CUR_GDRIVE_HASH

REM echo !CUR_SEA_HASH!>"%SEA_HASH_FILE%"
REM echo !CUR_GDRIVE_HASH!>"%GDRIVE_HASH_FILE%"

REM supposedly this works better to avoid extra carriage returns and such extra stuff
<nul set /p "=!CUR_SEA_HASH!" > "%SEA_HASH_FILE%"
<nul set /p "=!CUR_GDRIVE_HASH!" > "%GDRIVE_HASH_FILE%"

del "%DB_SEA%.bak" >nul 2>&1
del "%DB_GDRIVE%.bak" >nul 2>&1

:: =========================================================
:: TRIM LOG IF TOO LARGE (SAFE VERSION)
:: =========================================================

if exist "%LOGFILE%" (
    for %%A in ("%LOGFILE%") do (
        if %%~zA GTR !MAX_LOG_SIZE! (

            set "TMPLOG=!LOGFILE!.tmp"

            powershell -NoProfile -Command ^
              "Get-Content '!LOGFILE!' -Tail 80 | Set-Content '!TMPLOG!'"

            if exist "!TMPLOG!" (
                move /y "!TMPLOG!" "!LOGFILE!" >nul
            )
            call :log LOGFILE_TRIMMED Trimming logfile to 80 lines
            echo LOGFILE_TRIMMED Trimming logfile to 80 lines
        )
    )
)

echo Sync complete and hashes saved
goto :end


:: =========================================================

:GetHash
echo certutil -hashfile %1 SHA256 ^| findstr /v "hash CertUtil"
::for /f "skip=1 tokens=1" %%H in ('
for /f %%H in ('
    certutil -hashfile %1 SHA256 ^| findstr /v "hash CertUtil"
') do (
    echo HASH found for %1:: %%H
    set "%2=%%H"    
    goto :eof
)
echo NO HASH FOUND FOR %1
set %2=%1
goto :eof

:log

echo [%date% %time%] %*>>"%LOGFILE%"
goto :eof


:restore
echo Merge failed - restoring backups
call :log ERROR_MERGE_FAILED The DB merge failed for some reason, restoring backup databases and exiting
copy /y "%DB_SEA%.bak" "%DB_SEA%" >nul
copy /y "%DB_GDRIVE%.bak" "%DB_GDRIVE%" >nul
goto :error

:cleanup
del "%DB_SEA%.bak" >nul 2>&1
del "%DB_GDRIVE%.bak" >nul 2>&1
goto :end

:error
echo ERROR starting merge KeePass databases: Key files NOT FOUND, check script for errors
call :log ERROR_NO_FILE One or more files not found, not attempting any merges, exiting. Check script for errors.
exit /b 1

:end
exit /b 0
