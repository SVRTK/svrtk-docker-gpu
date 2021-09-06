@echo off

:: reconDirClean.bat - clean recon directory (except TempInputSeries)

:: Create fresh pride/recon dirs
ECHO Cleaning recon folder ...

:: Make temp copy of recon (to preserve latest DICOMs in TempInputSeries sent from PRIDE whilst we clean)
ROBOCOPY C:\svrtk-docker-gpu\recon C:\svrtk-docker-gpu\recon-tmp /E

:: Delete recon dir
RD /S /Q C:\svrtk-docker-gpu\recon

:: Rebuild pride/pride dir
ROBOCOPY C:\svrtk-docker-gpu\recon-tmp\pride C:\svrtk-docker-gpu\recon\pride /E

:: Remove old logs
DEL /S /Q C:\svrtk-docker-gpu\recon\pride\logs\*.txt

:: NB: not going to purge TempInputSeries or TempOutputSeries as done elsewhere or by PRIDE

:: Remove recon-tmp
RD /S /Q C:\svrtk-docker-gpu\recon-tmp

ECHO DONE

exit