#!/bin/bash

# reconDirClean.bash - clean recon directory (except TempInputSeries)

userName=$USER
dockerImageFolderName=svrtk-docker-gpu

# Create fresh pride/recon dirs
echo "Cleaning recon folder ..."

# Make temp copy of recon (to preserve latest DICOMs in TempInputSeries sent from PRIDE whilst we clean)
cp -r /home/$userName/$dockerImageFolderName/recon /home/$userName/$dockerImageFolderName/recon-tmp

# Delete recon dir
rm -rf /home/$userName/$dockerImageFolderName/recon

# Rebuild pride/pride dir
mkdir -p /home/$userName/$dockerImageFolderName/recon/pride
cp -r /home/$userName/$dockerImageFolderName/recon-tmp/pride/* /home/$userName/$dockerImageFolderName/recon/pride

# Remove old logs
rm /home/$userName/$dockerImageFolderName/recon/pride/logs/*.txt

# Purge TempInputSeries
rm -rf /home/$userName/$dockerImageFolderName/recon/pride/TempInputSeries/DICOM
rm -f /home/$userName/$dockerImageFolderName/recon/pride/TempInputSeries/DICOMDIR

# NB: TempOutputSeries not purged otherwise export to scanner would fail

# Remove recon-tmp
rm -rf /home/$userName/$dockerImageFolderName/recon-tmp

echo "DONE"
