@echo off

:: StartSVR.bat - Wrapper script for performing SVR via Pride

:: Docker image name (default: svrtk-docker-gpu)
set hostName=%COMPUTERNAME%
set "dockerImageName=fetalsvrtk/svrtk:pride-svr-docker-0.2.0"
ECHO Using Docker Image: %dockerImageName%

:: Clear TempOutputSeries
ECHO Cleaning TempOutputSeries DICOMs ...
RD /S /Q C:\svrtk-docker-gpu\recon\pride\TempOutputSeries\DICOM
DEL /S /Q C:\svrtk-docker-gpu\recon\pride\TempOutputSeries\DICOMDIR
ECHO DONE

:: Convert DICOMs from PRIDE to nifti, and, copy to recon folder
ECHO Converting DICOMs to nifti ...
wsl.exe docker run --rm -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% /home/scripts/svr_dcm2nii.bash > C:\svrtk-docker-gpu\recon\pride\logs\log_svr_dcm2nii.txt
ECHO DONE

:: Run SVRTK GPU Docker reconstruction
ECHO Running SVR reconstruction ...
wsl.exe docker run --rm -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% /home/scripts/docker-recon-brain-auto.bash /home/recon/ -1 -1 > C:\svrtk-docker-gpu\recon\pride\logs\log_svrtk_docker_gpu.txt
ECHO DONE

:: Convert SVR nifti to DICOM, and, copy to TempOutputSeries
ECHO Converting SVR nifti to DICOM ...
wsl.exe docker run --rm -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% python /home/scripts/svr_nii2pridedcm.py > C:\svrtk-docker-gpu\recon\pride\logs\log_svr_nii2pridedcm.txt

:: Create DICOMDIR file
wsl.exe docker run --rm -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% /home/scripts/svr_make_dicomdir.bash >> C:\svrtk-docker-gpu\recon\pride\logs\log_svr_nii2pridedcm.txt
ECHO DONE

:: Save Recon Directory
ECHO Saving recon directory ...
powershell.exe C:\svrtk-docker-gpu\scripts\reconDirSave.bat
ECHO DONE

:: Copy files to pnraw - nb: KCL specific script
if "%hostName%" EQU "PRIDESVR02-PC" (
	ECHO Copying files to pnraw01 ...
	wsl.exe /mnt/c/svrtk-docker-gpu/scripts/scp_recon_dir.bash > C:\svrtk-docker-gpu\recon\pride\logs\log_scp_recon.txt
	ECHO DONE
)

:: Clean Recon Directory
ECHO Cleaning recon directory ...
powershell.exe C:\svrtk-docker-gpu\scripts\reconDirClean.bat
ECHO DONE