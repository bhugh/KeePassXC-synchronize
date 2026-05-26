**WINDOWS BATCH FILE TO SYNCHRONIZE TWO KEEPASS DATABASES USING KEEPASSXC-CLI.EXE**

The purpose of this windows batch script is to allow the use of two different virtual drives to synchronize your KeePassXC database across different devices
and keep those two always in sync.

In KeePass this is fairly simple to do with plug-ins.  However, KeePassXC uses one monolithic database, so if you need to synchronize among
different virtual drive services - perhaps to make the database available on various devices, or to more robustly
avoid outages - this creates a problem.  

Fortunately it is fairly simple to synchronize different database using the command-line version, keepassxc-cli.exe.

The batch file contains the logic to do these synchronizations, while updating and synchronizing the two files only in the direction(s) required,
and doing nothing when neither file has changed.

I store the script as a windows batch file located in my documents directory (other locations are possible) and
then call it regularly using Windows Task Scheduler. Here is how I set up the schedule in Windows Task Scheduler:

 - A Task Scheduler trigger sets the script to run once at day at a certain time. So the Trigger is "On a schedule" "Daily" at a certain time. Then under "Advanced Settings" below that, repeat task every "5 minutes" for a duration "1 day".
 - Thus it starts once a day and then repeats every 5 minutes throughout the day.  The next day it restarts and runs every 5 minutes again.
 - Setting up the schedule this way ensures the script runs regularly throughout the day every day.

If there are no changes to either file, the script simply exits very quickly.  Thus it can be run every 5 minutes, 10, 30 or whatever you like, because most of the time it simply checks the hashes of the database files, then exits.
Only when changes have been made does it actually synchronize the files.

The script can also be run manually from the command line, which is helpful for setup, testing, and troubleshooting.

If anything goes wrong in the synchronization (error returned by KeePassXC-cli) the script reverts to a backup copy of the files it made before starting.   

It saves a log file with records of updates, and which direction, as well as errors in Documents/KeePassAutomergeLogs

The script can be set up to synchronize the database held in any two virtual drives - Microsoft, Dropbox, Google Drive, SeaDrive, NextCloud, etc etc

If it needs to update the "main" database, the one kept open by KeePassXC GUI for me the use throughout the day (which in this script is the Google Drive database), then it 
closes the KeePassXC GUI, then reopens it again afterwards, minimized to the try.  This is necessary because KeePassXC locks the database whenever it is opened in the GUI,
preventing the script from updating that version of the database if the other one is changed (ie, by a remote copy of KeePass working on that virtual drive on another device).

To do that (or, in fact, do any of the other merges etc that the script does), you will need a password-protected database - keyfiles might be possible by altering the respective keepassxc-cli.exe lines below

When opening the KeePassXC GUI minimized to the tray, it also opens the DB with the password (see below) because that is what I prefer.  You can edit the script to change this behavior.

Password is saved as a variable set within the script - there are other ways to do it that may be more secure, but that is the simplest.
