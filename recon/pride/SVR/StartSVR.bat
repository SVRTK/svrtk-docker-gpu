@echo off

:: Docker image name (default: svrtk-docker-gpu)
set "dockerImageName=svrtk-docker-gpu"
ECHO Using Docker Image: %dockerImageName%

:: Convert DICOMs from PRIDE to nifti, and, copy to recon folder
ECHO Converting DICOMs to nifti ...
wsl.exe docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% /home/scripts/svr_dcm2nii.bash > C:\svrtk-docker-gpu\recon\pride\SVR\log_svr_dcm2nii.txt
ECHO DONE

:: Run SVRTK GPU Docker reconstruction
ECHO Running SVR reconstruction ...
wsl.exe docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% /home/scripts/docker-recon-brain-auto.bash /home/recon/ > C:\svrtk-docker-gpu\recon\pride\SVR\log_svrtk_docker_gpu.txt
ECHO DONE

:: Convert SVR nifti to DICOM, and, copy to TempOutputSeries
ECHO Converting SVR nifti to DICOM ...
wsl.exe docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% python /home/scripts/svr_nii2pridedcm.py > C:\svrtk-docker-gpu\recon\pride\SVR\log_svr_nii2pridedcm.txt

:: Create DICOMDIR file
wsl.exe docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% /home/scripts/svr_make_dicomdir.bash >> C:\svrtk-docker-gpu\recon\pride\SVR\log_svr_nii2pridedcm.txt
ECHO DONE

:: Archive reconstruction (limit to 1)
ECHO Archiving previous reconstruction ...
RD /S /Q C:\svrtk-docker-gpu\previous-recon
ROBOCOPY C:\svrtk-docker-gpu\recon C:\svrtk-docker-gpu\previous-recon /E
ECHO DONE

:: Purge/Create fresh pride/recon dirs
ECHO Cleaning recon folder ...
RD /S /Q C:\svrtk-docker-gpu\recon
ROBOCOPY C:\svrtk-docker-gpu\previous-recon\pride C:\svrtk-docker-gpu\recon\pride /E
DEL /S /Q C:\svrtk-docker-gpu\recon\pride\logs\
DEL /S /Q C:\svrtk-docker-gpu\recon\pride\TempInputSeries\
DEL /S /Q C:\svrtk-docker-gpu\recon\pride\TempOutputSeries\
ECHO DONE