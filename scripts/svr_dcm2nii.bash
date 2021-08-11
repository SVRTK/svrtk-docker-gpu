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

#PATH="$PATH:/home/MIRTK/build/bin:/home/MIRTK/build/lib/tools" # within Docker container

# Setup
svrtkDockerDir=/mnt/c/svrtk-docker-gpu
inFolder=$svrtkDockerDir/pride/TempInputSeries/
dcmFolder=$svrtkDockerDir/pride/TempInputSeries/DICOM/
niiFolder=$svrtkDockerDir/pride/TempInputSeries/nii/
outFolder=$svrtkDockerDir/recon/
mkdir $niiFolder

# Unpack dicoms
#dcm2niix -z y -o $niiFolder -f %t_%v_%s_%p $inFolder

# Unpack dicoms using dcm2niix development branch - see: https://github.com/rordenlab/dcm2niix/issues/529
/home/tr17/reconstruction-software/dcm2niix/build/bin/dcm2niix -z y -o $niiFolder -f %t_%v_%s_%p $inFolder


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
	/home/tr17/reconstruction-software/MIRTK/build/bin/mirtk extract-image-region ${niiFilenames[$iF]} stk.nii.gz -split t
	
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