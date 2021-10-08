#!/bin/bash

# reconDirSave.bash - save recon dir as previous-recon

userName=$USER
dockerImageFolderName=svrtk-docker-gpu

# Archive reconstruction (limit to 1)
rm -rf /home/$userName/$dockerImageFolderName/previous-recon
cp -r /home/$userName/$dockerImageFolderName/recon /home/$userName/$dockerImageFolderName/previous-recon
