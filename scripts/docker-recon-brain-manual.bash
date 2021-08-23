#!/bin/bash


echo
echo "-----------------------------------------------------------------------------"
echo "RUNNING MANUAL SVR RECONSTRCTION"
echo "-----------------------------------------------------------------------------"
echo


default_recon_dir=$1


# Paths
mirtk_path=/home/MIRTK/build/bin


test_dir=${default_recon_dir}
if [[ ! -d ${test_dir} ]];then
	echo "ERROR: NO INPUT FOLDER FOUND !!!!!"
	exit
fi 

source ~/.bashrc

cd ${default_recon_dir}
main_dir=$(pwd)


# Parameters
res=128
all_num_lab=1
current_lab=1

#CHANGE BACK TO 4 AFTER TESTING !!!!
num_packages=1

# TODO: implement check in case slice thickness inconsistent across stacks
if [[ -f "${default_recon_dir}/log_slice_thickness.txt" ]]; then
	default_thickness=`cat "${default_recon_dir}/log_slice_thickness.txt" | awk -F' ' '{print $1}'`
else
	echo "WARNING: Setting default_thickness = 2.5"
	default_thickness=2.5
fi

#FOR TESTING ONLY - CHANGE TO 0.85 AFTER TESTING
output_resolution=0.85


roi_recon_mode=(0)
roi_recon=("SVR")
roi_names=("brain")
roi_ids=(1)


stack_names=(`ls stack*.nii*`)
nStacks=(`ls stack*.nii* | wc -l`)
mask_name=(`ls *mask*.nii*`)

IFS=$'\n' read -rd '' -a all_stacks <<<"$stack_names"


echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo
echo "RUNNING RECONSTRUCTION ..."
echo


cd ${main_dir}


${mirtk_path}/mirtk reconstruct ${main_dir}/${roi_recon[j]}-output.nii.gz ${nStacks} ${stack_names[@]} -mask $mask_name -default_thickness ${default_thickness} -svr_only -remote -iterations 3 -structural -resolution ${output_resolution}


test_file=${main_dir}/${roi_recon[j]}-output.nii.gz
if [[ -f ${test_file} ]];then

	# TAR - pad to cuboid for Philips import
	cp ${main_dir}/${roi_recon[j]}-output.nii.gz ${main_dir}/${roi_recon[j]}-output-withoutPadding.nii.gz
	${mirtk_path}/mirtk resample-image ${main_dir}/${roi_recon[j]}-output.nii.gz ${main_dir}/${roi_recon[j]}-output.nii.gz -imsize 180 180 180
	
	echo "Reconstruction was successful: " ${roi_recon[j]}-output.nii.gz

else 

	echo "Reconstruction failed ... " 

fi
	


echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo
