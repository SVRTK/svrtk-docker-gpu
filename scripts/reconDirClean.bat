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

:: Purge TempInputSeries
RD /S /Q C:\svrtk-docker-gpu\recon\pride\TempInputSeries\DICOM
DEL /S /Q C:\svrtk-docker-gpu\recon\pride\TempInputSeries\DICOMDIR

:: NB: TempOutputSeries not purged otherwise export to scanner would fail

:: Remove recon-tmp
RD /S /Q C:\svrtk-docker-gpu\recon-tmp

ECHO DONE

exit