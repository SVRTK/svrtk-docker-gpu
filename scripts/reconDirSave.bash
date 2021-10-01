#!/bin/bash

# reconDirSave.bash - save recon dir as previous-recon

userName=$USER
dockerImageName=svrtk-docker-gpu

# Archive reconstruction (limit to 1)
rm -rf /home/$userName/$dockerImageName/previous-recon
cp -r /home/$userName/$dockerImageName/recon /home/$userName/$dockerImageName/previous-recon
