#!/bin/bash

# StartSVR.bash - Wrapper script for performing SVR via Pride

# Admin
userName=$USER

# Docker image name (default: svrtk-docker-gpu)
dockerImageName=fetalsvrtk/svrtk:svrtk-docker-gpu
dockerImageFolderName=svrtk-docker-gpu
echo "Using Docker Image:" $dockerImageName

# Clear TempOutputSeries
echo "Cleaning TempOutputSeries DICOMs ..."
rm -rf /home/$userName/$dockerImageFolderName/recon/pride/TempOutputSeries/DICOM
rm -f /home/$userName/$dockerImageFolderName/recon/pride/TempOutputSeries/DICOMDIR
echo "DONE"

# Convert DICOMs from PRIDE to nifti, and, copy to recon folder
echo "Converting DICOMs to nifti ..."
docker run -v "/home/$userName/$dockerImageFolderName/recon":/home/recon $dockerImageName /home/scripts/svr_dcm2nii.bash > /home/$userName/$dockerImageFolderName/recon/pride/logs/log_svr_dcm2nii.txt
echo "DONE"

# Run SVRTK GPU Docker reconstruction
echo "Running SVR reconstruction ..."
docker run --gpus all -v "/home/$userName/$dockerImageFolderName/recon":/home/recon $dockerImageName /home/scripts/docker-recon-brain-auto.bash /home/recon/ > /home/$userName/$dockerImageFolderName/recon/pride/logs/log_svrtk_docker_gpu.txt
echo "DONE"

# Convert SVR nifti to DICOM, and, copy to TempOutputSeries
echo "Converting SVR nifti to DICOM ..."
docker run -v "/home/$userName/$dockerImageFolderName/recon":/home/recon $dockerImageName python /home/scripts/svr_nii2pridedcm.py > /home/$userName/$dockerImageFolderName/recon/pride/logs/log_svr_nii2pridedcm.txt

# Create DICOMDIR file
docker run -v "/home/$userName/$dockerImageFolderName/recon":/home/recon $dockerImageName /home/scripts/svr_make_dicomdir.bash >> /home/$userName/$dockerImageFolderName/recon/pride/logs/log_svr_nii2pridedcm.txt
echo "DONE"

# Change Recon Directory Permissions in Container to Match Host User
echo "Adjusting recon directory permissions ..."
uid=$(id -u)
gid=$(id -g)
docker run -v "/home/$userName/$dockerImageFolderName/recon":/home/recon $dockerImageName bash -c "chown -R $uid:$gid /home/recon"
docker run -v "/home/$userName/$dockerImageFolderName/recon":/home/recon $dockerImageName bash -c "chmod -R 1775 /home/recon"
echo "DONE"

# Save Recon Directory
echo "Saving recon directory ..."
/home/$userName/$dockerImageFolderName/scripts/reconDirSave.bash
echo "DONE"

# Copy files to pnraw
echo "Copying files to pnraw01 ..."
/home/$userName/$dockerImageFolderName/scripts/scp_recon_dir.bash > /home/$userName/$dockerImageFolderName/recon/pride/logs/log_scp_recon.txt
echo "DONE"

# Clean Recon Directory
echo "Cleaning recon directory ..."
/home/$userName/$dockerImageFolderName/scripts/reconDirClean.bash
echo "DONE"

