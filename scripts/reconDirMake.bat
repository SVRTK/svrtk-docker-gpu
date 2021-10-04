@echo off

:: reconDirMake.bat - make clean recon dir
:: note - PRIDE itself makes the TempInputSeries folder

:: Make recon folders
ECHO Making new recon directory folders ...
MD C:\svrtk-docker-gpu\recon\pride\logs
MD C:\svrtk-docker-gpu\recon\pride\TempInputSeries
MD C:\svrtk-docker-gpu\recon\pride\TempOutputSeries
ECHO DONE