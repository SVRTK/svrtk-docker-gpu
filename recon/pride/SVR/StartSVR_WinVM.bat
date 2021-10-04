@echo off

:: SSH_StartSVR.bat - Script to start SVR process on Ubuntu via SSH
::
:: Note - requires SSH keys configured between Host and VM

:: Admin
set "userName=tr17"
set "hostName=pridesvr02-pc"
set "vmName=pridesvr03-vm"
set "dockerImageName=svrtk-docker-gpu"

:: Copy 2D stack DICOMs from VM to Host
ECHO Copying stacks from VM to Host ...
ssh %username%@%hostName% bash -c 'cp -r /home/%username%/%vmName%/TempInputSeries /home/%username%/%dockerImageName%/recon/pride/'
ECHO DONE

:: Initiate Docker container on Host
ECHO Performing SVR on Host ...
ssh %username%@%hostName% bash -c '/home/%username%/%dockerImageName%/recon/pride/SVR/StartSVR.bash'
ECHO DONE

:: Copy 3D SVR DICOMs from Host to VM
ECHO Copying 3D SVR data from Host to VM ...
ssh %username%@%hostName% bash -c 'cp -r /home/%username%/%dockerImageName%/recon/pride/TempOutputSeries/ /home/%username%/%vmName%/'
ECHO DONE
