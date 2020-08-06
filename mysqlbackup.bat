:: Tell CSV Creator to stop ... it interferes with some of the backups, which then
:: interfere with the re-migrations, and the whole thing locks up!  It will take a 
:: while to stop, not a problem though as the threads will stop as their queries
:: complete.  We pause for 5 minutes to let things clear out.

echo "Stopping CSV Creator's TOMCAT ..."
sc stop Tomcat8
echo "Sleeping for 5 minutes ..."
TIMEOUT /T 300  1>NUL 2>&1 

:: Just in case it is still running ... kill with EXTREME PREJUDICE!!
echo "Stopping CSV Creator's TOMCAT via TASKKILL just in case it is still running ... "
TASKKILL /F /T /IM TOMCAT8.EXE
TIMEOUT /T 10  1>NUL 2>&1 

:: If the time is less than two digits insert a zero so there is no space to break the filename
:: If you have any regional date/time issues call this include: getdate.cmd  credit: Simon Sheppard for this cmd - untested
:: call getdate.cmd

set year=%DATE:~10,4%
set day=%DATE:~7,2%
set mnt=%DATE:~4,2%
set hr=%TIME:~0,2%
set min=%TIME:~3,2%

IF %day% LSS 10 SET day=0%day:~1,1%
IF %mnt% LSS 10 SET mnt=0%mnt:~1,1%
IF %hr% LSS 10 SET hr=0%hr:~1,1%
IF %min% LSS 10 SET min=0%min:~1,1%

set backuptime=%year%-%mnt%-%day%-%hr%-%min%
echo %backuptime%


:: SETTINGS AND PATHS 
:: Note: Do not put spaces before the equal signs or variables will fail

:: Name of the database user with rights to all tables
set dbuser=mysqlbackup

:: Password for the database user
set dbpass=backmeup!2

:: MySQL dump EXE Path
set mysqldumpexe="C:\Program Files\MySQL\MySQL Server 5.6\bin\mysqldump.exe"

:: MySQL EXE Path
set mysqlexe="C:\Program Files\MySQL\MySQL Server 5.6\bin\mysql.exe"

:: Error log path
set backupfldr="F:\Backups\backupfiles"

:: Path to data folder which may differ from install dir
set datafldr="E:\MySQL\MySQL Server 5.6\data"

:: Number of days to retain backup files ... plus 1 
set retaindays=2

:: Path to Tomcat logs
set tomcatlogdir="E:\Apache Software Foundation\Tomcat 8.5\logs"

:: Number of days to retain Tomcat logs ... plus 1 
set logretaindays=89

:: Path to CSVCreator Data
set csvcreatordatadir="E:\ProgramData\CSVCreator\webapps\CSVCreator\data"

:: DONE WITH SETTINGS

@echo "Stopping any remaining 'om_csv_v2' connections ..."
DEL F:\Backups\kill_process.txt >NUL 2>&1
%mysqlexe% -s -e "SELECT CONCAT('KILL ',id,';') AS run_this FROM information_schema.processlist WHERE user='om_csv_v2' INTO OUTFILE 'F:/Backups/kill_process.txt';" --user=%dbuser% --password=%dbpass%
%mysqlexe% -s -e "source F:/Backups/kill_process.txt" --user=%dbuser% --password=%dbpass%

DEL F:\Backups\kill_process.txt >NUL 2>&1

:: GO FORTH AND BACKUP EVERYTHING!

:: Switch to the data directory to enumerate the folders
pushd %datafldr%

echo "Pass each name to mysqldump.exe and output an individual .sql file for each"

:: turn on if you are debugging
@echo on

FOR /D %%F IN (*) DO (

IF NOT [%%F]==[performance_schema] IF NOT [%%F]==[mysql] IF NOT [%%F]==[sys] IF NOT [%%F]==[one_messenger] (
SET %%F=!%%F:@002d=-!
if not exist %backupfldr%\%backuptime% (
      mkdir %backupfldr%\%backuptime%
 )
%mysqldumpexe% --user=%dbuser% --password=%dbpass% -R -E --triggers --single-transaction --max_allowed_packet=512M --log-error="%backupfldr%\%backuptime%\%%F_dumperrors.txt" %%F > "%backupfldr%\%backuptime%\%%F.sql"

) ELSE (
echo Skipping DB backup for performance_schema and mysql
)
)

REM echo "Stopping MySQL to backup logs ..."
REM sc stop MySQL56

REM echo "Waiting for MySQL stop"
REM :LOOP
REM sc query MySQL56 | FIND "STATE" | FIND "STOPPED"
REM if errorlevel 1  (
	REM TIMEOUT /T 60  1>NUL 2>&1
	REM time /t
	REM GOTO :LOOP
REM )

REM :: echo "Sleeping for 30 minutes ..."
REM :: TIMEOUT /T 1800  1>NUL 2>&1 

REM COPY %datafldr%\FIG-COMMUNICATO-slow.log "%backupfldr%\%backuptime%"
REM DEL %datafldr%\FIG-COMMUNICATO-slow.log 2>NUL 1>NUL

REM COPY  %datafldr%\FIG-COMMUNICATO.err "%backupfldr%\%backuptime%"
REM DEL %datafldr%\FIG-COMMUNICATO.err 2>NUL 1>NUL

REM COPY  %datafldr%\FIG-COMMUNICATO.log "%backupfldr%\%backuptime%"
REM DEL %datafldr%\FIG-COMMUNICATO.log 2>NUL 1>NUL

echo "Deleting Tomcat logs older than %logretaindays% days ..."
Forfiles -p %tomcatlogdir% -s -m *.* -d -%logretaindays% -c "cmd /c del /q @path"

echo "Deleting CSVCreator data files older than %retaindays% days ..."
Forfiles -p %csvcreatordatadir% -s -m *.* -d -%retaindays% -c "cmd /c del /q @path"

echo "Deleting files older than %retaindays% days ..."
Forfiles -p %backupfldr% -s -m *.* -d -%retaindays% -c "cmd /c del /q @path"
:: Delete empty directories and report on file counts in the directories
echo "Deleting empty backup directories and Generating Report ..."
ROBOCOPY %backupfldr% %backupfldr% /S /MOVE 

echo "done"

REM echo "Restarting MySQL ..."
REM sc start MySQL56

REM TIMEOUT /T 300 1>NUL 2>&1

echo "Restarting CSV Creator's TOMCAT ..."
sc start Tomcat8

::return to the main script dir on end
popd

:: LOG ROTATION -- 2018-07-16
DEL BKPLOG8.txt 2>NUL >NUL
rename BKPLOG7.txt BKPLOG8.txt 2>NUL 1>NUL
rename BKPLOG6.txt BKPLOG7.txt 2>NUL 1>NUL
rename BKPLOG5.txt BKPLOG6.txt 2>NUL 1>NUL
rename BKPLOG4.txt BKPLOG5.txt 2>NUL 1>NUL
rename BKPLOG3.txt BKPLOG4.txt 2>NUL 1>NUL
rename BKPLOG2.txt BKPLOG3.txt 2>NUL 1>NUL
rename BKPLOG1.txt BKPLOG2.txt 2>NUL 1>NUL 
START CMD.EXE /C "TIMEOUT /T 60  1>NUL 2>NUL & COPY bkp_log.txt BKPLOG1.txt 2>NUL >NUL"
START CMD.EXE /C "TIMEOUT /T 300  1>NUL 2>NUL & del bkp_log.txt 2>NUL >NUL""
