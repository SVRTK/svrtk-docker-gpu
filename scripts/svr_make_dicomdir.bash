#!/bin/bash

### svr_make_dicomdir 
#
# - creates DICOMDIR, moves alongside DICOM folder
# - nb: very hacky code because do not have permissions to write to C:\
# - MC was very specific about how to create DICOMDIR based on file directory structure
#
# Requires:
# - WSL
# - sudo apt-get install dcmtk
#
# Tom Roberts (t.roberts@kcl.ac.uk)
#
###########################################################

echo
echo "Creating DICOMDIR ..."

prideDir=/mnt/c/svrtk-docker-gpu/pride

mkdir $prideDir/TempOutputSeries/tempDir
mv $prideDir/TempOutputSeries/DICOM $prideDir/TempOutputSeries/tempDir/DICOM
cd $prideDir/TempOutputSeries
/usr/bin/dcmmkdir +id 'tempDir' +r
mv $prideDir/TempOutputSeries/tempDir/DICOM $prideDir/TempOutputSeries
rm -r tempDir

echo "DICOMDIR created."
echo
