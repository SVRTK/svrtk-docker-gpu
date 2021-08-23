@echo off

:: StartSVR.bat - Wrapper script for performing SVR via Pride

:: Docker image name (default: svrtk-docker-gpu)
set "dockerImageName=svrtk-docker-gpu"
ECHO Using Docker Image: %dockerImageName%

:: Convert DICOMs from PRIDE to nifti, and, copy to recon folder
ECHO Converting DICOMs to nifti ...
wsl.exe docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% /home/scripts/svr_dcm2nii.bash > C:\svrtk-docker-gpu\recon\pride\logs\log_svr_dcm2nii.txt
ECHO DONE

:: Run SVRTK GPU Docker reconstruction
ECHO Running SVR reconstruction ...
wsl.exe docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% /home/scripts/docker-recon-brain-auto.bash /home/recon/ > C:\svrtk-docker-gpu\recon\pride\logs\log_svrtk_docker_gpu.txt
ECHO DONE

:: Convert SVR nifti to DICOM, and, copy to TempOutputSeries
ECHO Converting SVR nifti to DICOM ...
wsl.exe docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% python /home/scripts/svr_nii2pridedcm.py > C:\svrtk-docker-gpu\recon\pride\logs\log_svr_nii2pridedcm.txt

:: Create DICOMDIR file
wsl.exe docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% /home/scripts/svr_make_dicomdir.bash >> C:\svrtk-docker-gpu\recon\pride\logs\log_svr_nii2pridedcm.txt
ECHO DONE

:: Clean Directories
cmd.exe C:\svrtk-docker-gpu\scripts\reconDirClean.bat