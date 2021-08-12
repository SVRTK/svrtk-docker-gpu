@echo off

:: Docker image name (default: svrtk-docker-gpu)
set "dockerImageName=svrtk-docker-gpu"
echo Using Docker Image: %dockerImageName%

:: Convert DICOMs from PRIDE to nifti, and, copy to recon folder
echo Converting DICOMs to nifti ...
wsl.exe docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% /home/scripts/svr_dcm2nii.bash > C:\svrtk-docker-gpu\recon\pride\SVR\log_svr_dcm2nii.txt
ECHO DONE

:: Run SVRTK GPU Docker reconstruction
echo Running SVR reconstruction ...
wsl.exe docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% /home/scripts/docker-recon-brain.bash /home/recon/ > C:\svrtk-docker-gpu\recon\pride\SVR\log_svrtk_docker_gpu.txt
ECHO DONE

:: Convert SVR nifti to DICOM, and, copy to TempOutputSeries
echo Converting SVR nifti to DICOM ...
wsl.exe docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% python /home/scripts/svr_nii2pridedcm.py > C:\svrtk-docker-gpu\recon\pride\SVR\log_svr_nii2pridedcm.txt

:: Create DICOMDIR file
wsl.exe docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu/recon":/home/recon %dockerImageName% /home/scripts/svr_make_dicomdir.bash >> C:\svrtk-docker-gpu\recon\pride\SVR\log_svr_nii2pridedcm.txt
ECHO DONE
