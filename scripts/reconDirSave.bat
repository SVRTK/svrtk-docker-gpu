@echo off

:: reconDirSave.bat - save recon dir as previous-recon

:: Archive reconstruction (limit to 1)
RD /S /Q C:\svrtk-docker-gpu\previous-recon
ROBOCOPY C:\svrtk-docker-gpu\recon C:\svrtk-docker-gpu\previous-recon /E

exit
