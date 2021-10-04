#!/bin/bash

# reconDirClean.bash - clean recon directory (except TempInputSeries)

userName=$USER
dockerImageName=svrtk-docker-gpu

# Create fresh pride/recon dirs
echo "Cleaning recon folder ..."

# Make temp copy of recon (to preserve latest DICOMs in TempInputSeries sent from PRIDE whilst we clean)
cp -r /home/$userName/$dockerImageName/recon /home/$userName/$dockerImageName/recon-tmp

# Delete recon dir
rm -rf /home/$userName/$dockerImageName/recon

# Rebuild pride/pride dir
mkdir -p /home/$userName/$dockerImageName/recon/pride
cp -r /home/$userName/$dockerImageName/recon-tmp/pride/* /home/$userName/$dockerImageName/recon/pride

# Remove old logs
rm /home/$userName/$dockerImageName/recon/pride/logs/*.txt

# Purge TempInputSeries
rm -rf /home/$userName/$dockerImageName/recon/pride/TempInputSeries/DICOM
rm -f /home/$userName/$dockerImageName/recon/pride/TempInputSeries/DICOMDIR

# NB: TempOutputSeries not purged otherwise export to scanner would fail

# Remove recon-tmp
rm -rf /home/$userName/$dockerImageName/recon-tmp

echo "DONE"
