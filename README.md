::
:: WINDOWS BATCH FILE TO SYNCHRONIZE TWO KEEPASS DATABASES USING KEEPASSXC-CLI.EXE
::
:: The purpose is so that you can use two different virtual drives to synchronize your KeePassXC database across different devices
:: and keep those two always in sync.
::
:: In KeePass this is fairly simple to do with plug-ins.  However, KeePassXC uses one monolithic database, so if you need to synchronize among
:: different virtual drive services - perhaps to make the database available on various devices, or to more robustly
:: avoid outages - this creates a problem.  
::
:: Fortunately it is fairly simple to synchronize different database using the command-line version, keepassxc-cli-exe.
::
:: The batch file contains the logic to do so, while updating and synchronizing the two files only in the direction(s) required,
:: and doing nothing when neither file has changed.
::
:: I store the script as a windows batch file located in my documents directory (other locations are possible) and
:: then call it regularly using Windows Task Scheduler.
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
