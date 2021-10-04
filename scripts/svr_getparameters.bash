#!/bin/bash

### svr_getparameters - fetch parameters for SVR from DICOM/nifti files
#
# Tom Roberts (t.roberts@kcl.ac.uk)
#
###########################################################


# Message
echo "Fetching parameters ..."

# Setup
inFolder=/home/recon/pride/TempInputSeries/
dcmFolder=/home/recon/pride/TempInputSeries/DICOM/
niiFolder=/home/recon/pride/TempInputSeries/nii/
outFolder=/home/recon/
mkdir $niiFolder

# Get Parameters
# nb: assumes .json files generated using dcm2niix
cd $niiFolder
jsonFilenames=(`ls *.json`)
numJsonFiles=`ls *.json | wc -l` # nb: assumes series numbers end with 01, i.e.: 601, 701, etc.

# Write parameters to log file
iF=0
while [ $iF -lt `expr $numJsonFiles` ] ; do

	sliceThk=$(grep -F "SliceThickness" ${jsonFilenames[$iF]} | sed -e 's/[^0-9.]//g')
	SLICETHICKNESS[$iF]=$sliceThk
	echo ${SLICETHICKNESS[*]} > log_slice_thickness.txt
	
	iF=`expr $iF + 1`

done

# move log files to recon folder
mv $niiFolder/log_slice_thickness.txt $outFolder

echo "Parameters fetched ..."