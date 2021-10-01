#!/bin/bash

### scp_recon_dir - copy recon/ folder to FetalPreprocessing
#
# Script is specific to KCL infrastructure
#
# - IMPORTANT: requires SSH key copied to remote computer
# 		- use ssh-copy-id to copy SSH key to remote
# - gpubeastie01-pc used as gateway to pnraw01
#
# Tom Roberts (t.roberts@kcl.ac.uk)
#
###########################################################


# Setup
reconFolder=/mnt/c/svrtk-docker-gpu/recon
dicomFolder=/mnt/c/svrtk-docker-gpu/recon/pride/TempInputSeries/DICOM

remoteUser=tr17
remoteHost=gpubeastie01-pc.isd.kcl.ac.uk
remoteDir=/pnraw01/FetalPreprocessing

# Get Scan/Patient Info from DICOM
patID=$(dcmdump +P PatientID -s $dicomFolder/IM_0001 | awk -F "[][]" '{print $2}')
studyDate=$(dcmdump +P StudyDate -s $dicomFolder/IM_0001 | awk -F "[][]" '{print $2}')

YEAR="${studyDate:0:4}"
MONTH="${studyDate:4:2}" 
DAY="${studyDate:6:2}"
scanDate=$YEAR"_"$MONTH"_"$DAY

# Copy recon folder to FetalPreprocessing
patientFolder=$scanDate/$patID

echo "Copying to ... "$remoteHost":"$remoteDir/$patientFolder

ssh $remoteUser@$remoteHost "mkdir -p $remoteDir/$patientFolder"
ssh $remoteUser@$remoteHost "chmod -R 1775 $remoteDir/$scanDate" # Set sticky bits for other users

# rsync -r $reconFolder/* $remoteUser@$remoteHost:$remoteDir/$patientFolder		REM entire folder (unnecessary)
rsync -r $reconFolder/SVR-output.nii.gz $remoteUser@$remoteHost:$remoteDir/$patientFolder
rsync -r $reconFolder/stack*.nii.gz $remoteUser@$remoteHost:$remoteDir/$patientFolder
rsync -r $reconFolder/pride/logs $remoteUser@$remoteHost:$remoteDir/$patientFolder
rsync -r $reconFolder/log_slice_thickness.txt $remoteUser@$remoteHost:$remoteDir/$patientFolder/logs


