@echo off

:: reconDirClean.bat - archives existing recon / cleans recon directory

:: Archive reconstruction (limit to 1)
ECHO Archiving previous reconstruction ...
RD /S /Q C:\svrtk-docker-gpu\previous-recon
ROBOCOPY C:\svrtk-docker-gpu\recon C:\svrtk-docker-gpu\previous-recon /E
ECHO DONE

:: Purge/Create fresh pride/recon dirs
ECHO Cleaning recon folder ...
RD /S /Q C:\svrtk-docker-gpu\recon
ROBOCOPY C:\svrtk-docker-gpu\previous-recon\pride C:\svrtk-docker-gpu\recon\pride /E
:: /logs
DEL /S /Q C:\svrtk-docker-gpu\recon\pride\logs\*.txt
:: /TempInputSeries
RD /S /Q C:\svrtk-docker-gpu\recon\pride\TempInputSeries\DICOM
DEL /S /Q C:\svrtk-docker-gpu\recon\pride\TempInputSeries\DICOMDIR
:: /TempOutputSeries
RD /S /Q C:\svrtk-docker-gpu\recon\pride\TempOutputSeries\DICOM
DEL /S /Q C:\svrtk-docker-gpu\recon\pride\TempOutputSeries\DICOMDIR
ECHO DONE