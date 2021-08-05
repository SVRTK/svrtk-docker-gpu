:: notepad.exe

:: Convert DICOMs from PRIDE to nifti, and, copy to recon folder
wsl.exe /mnt/c/svrtk-docker-gpu/scripts/svr_dcm2nii.bash > C:\SVR\log_svr_dcm2nii.txt

:: Run SVRTK GPU Docker reconstruction
wsl.exe docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu":/home/ svrtk-docker-gpu /home/scripts/docker-recon-brain.sh /home/recon > C:\SVR\log_svrtk_docker_gpu.txt

:: Convert SVR nifti to DICOM, and, copy to TempOutputSeries
wsl.exe python3 /mnt/c/svrtk-docker-gpu/scripts/svr_nii2pridedcm.py > C:\SVR\log_svr_nii2pridedcm.txt

:: Create DICOMDIR file
wsl.exe /mnt/c/svrtk-docker-gpu/scripts/svr_make_dicomdir.bash >> C:\SVR\log_svr_nii2pridedcm.txt