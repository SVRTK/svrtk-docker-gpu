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

mkdir /mnt/c/TempOutputSeries/tempDir
mv /mnt/c/TempOutputSeries/DICOM /mnt/c/TempOutputSeries/tempDir/DICOM
cd /mnt/c/TempOutputSeries
/usr/bin/dcmmkdir +id 'tempDir' +r
mv /mnt/c/TempOutputSeries/tempDir/DICOM /mnt/c/TempOutputSeries
rm -r tempDir

echo "DICOMDIR created."
echo
