#!/bin/bash

### svr_dcm2nii - convert dicoms from Philips PRIDE to nifti
#
# Input:
# - multi-slice, multi-stack dicom files
#
# Output:
# - single dynamic nifti files named stack1.nii.gz ... stackN.nii.gz
#
# Requires:
# - WSL
# - sudo apt-get install dcm2niix pigz
# - local build of MIRTK
#
# Tom Roberts (t.roberts@kcl.ac.uk)
# Alena Uus   (alena.uus@kcl.ac.uk)
#
###########################################################


# Setup
inFolder=/home/recon/pride/TempInputSeries/
dcmFolder=/home/recon/pride/TempInputSeries/DICOM/
niiFolder=/home/recon/pride/TempInputSeries/nii/
outFolder=/home/recon/
getParametersScript=/home/scripts/svr_getparameters.bash
mkdir $niiFolder


# Unpack DICOMs 
# - using dcm2niix development branch - see: https://github.com/rordenlab/dcm2niix/issues/529
dcm2niix -z y -o $niiFolder -f %t_%v_%s_%p $inFolder

# Get Parameters
bash $getParametersScript

# Rename nifti files, move to SVR folder
cd $niiFolder
niiFilenames=(`ls *.nii.gz`)
numNiiFiles=`ls *.nii.gz | wc -l` # nb: assumes series numbers end with 01, i.e.: 601, 701, etc.

echo
echo "Number of Nifti files = "$numNiiFiles
echo
echo "Nifti filenames:"
printf '%s\n' "${niiFilenames[@]}"
echo

# Convert dynamics to individual stack.nii.gz
iF=0
iStk=0
niiFileNumberCtr=1
stackFileNumberCtr=1
while [ $iF -lt `expr $numNiiFiles` ] ; do
	
	# save dynamics as separate nifti
	mirtk extract-image-region ${niiFilenames[$iF]} stk.nii.gz -split t
	
	stackFilenames=(`ls stk*.nii.gz`)
	numStackFiles=`ls stk*.nii.gz | wc -l`

	# rename stacks stack1.nii.gz...stackN.nii.gz
	while [ $iStk -lt $numStackFiles ] ; do
		mv ${stackFilenames[$iStk]} stack$stackFileNumberCtr.nii.gz
		iStk=`expr $iStk + 1`
		stackFileNumberCtr=`expr $stackFileNumberCtr + 1`
	done
	iStk=0
	
	iF=`expr $iF + 1`
	niiFileNumberCtr=`expr $niiFileNumberCtr + 1`

done

# move nifti files to recon folder
mv $niiFolder/stack*.nii.gz $outFolder

# clean up
rm -r $niiFolder