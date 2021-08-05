#!/bin/bash


echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo


default_recon_dir=$1

mirtk_path=/home/MIRTK/build/bin
segm_path=/home/Segmentation_FetalMRI
check_path_brain=/home/Segmentation_FetalMRI/trained-models/checkpoints-brain-loc-2-labels
check_path_brain_cropped=/home/Segmentation_FetalMRI/trained-models/checkpoints-brain-loc-2-labels-cropped


test_dir=${default_recon_dir}
if [[ ! -d ${test_dir} ]];then
	echo "ERROR: NO INPUT FOLDER FOUND !!!!!"
	exit
fi 


# conda init bash
source ~/.bashrc

# cd ${segm_path}
#conda env create -f environment.yml
#conda env list
# conda activate Segmentation_FetalMRI


cd ${default_recon_dir}
main_dir=$(pwd)


res=128
all_num_lab=1
current_lab=1

#CHANGE BACK TO 4 AFTER TESTING !!!!
num_packages=4

#AUTOMATICALLY GUESS
default_thickness=2.5

#FOR TESTING ONLY - CHANGE TO 0.85 AFTER TESTING
output_resolution=0.85


roi_recon_mode=(0)
roi_recon=("SVR")
roi_names=("brain")
roi_ids=(1)


test_dir=cnn-out-files
if [[ -d ${test_dir} ]];then

	rm -r cnn-out-files*
	rm -r cnn-recon-res-files
	rm -r cnn-recon-stack-files
	rm -r cnn-recon-org-files
	rm -r cnn-recon-org-files-packages
	rm -r cnn-recon-mask-files*
	rm -r cnn-recon-org-files-packages
	rm -r cropped*
	rm *

fi


mkdir ${main_dir}/cnn-recon-org-files
find ${main_dir}/ -name "*.nii*" -exec cp {} ${main_dir}/cnn-recon-org-files \; 



echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo
echo "SPLITTING INTO PACKAGES ..."
echo

mkdir cnn-recon-org-files-packages
cp cnn-recon-org-files/* cnn-recon-org-files-packages


cd ${main_dir}
cd cnn-recon-org-files-packages

stack_names=$(ls *.nii*)

IFS=$'\n' read -rd '' -a all_stacks <<<"$stack_names"


echo "folder : " ${in_file_dir}

for ((i=0;i<${#all_stacks[@]};i++));
do

    ${mirtk_path}/mirtk extract-packages ${all_stacks[i]} ${num_packages}

    rm ${all_stacks[i]}
    rm package-template.nii.gz 

    echo " - " ${all_stacks[i]}
done



echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo
echo "INPUT FILES ..."
echo

cd ${main_dir}

stack_names=$(ls cnn-recon-org-files-packages/*.nii*)

IFS=$'\n' read -rd '' -a all_stacks <<<"$stack_names"


echo "folder : " ${in_file_dir}

for ((i=0;i<${#all_stacks[@]};i++));
do
    echo " - " ${all_stacks[i]}
done

echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo
echo "3D UNET SEGMENTATION ..."
echo

cd ${main_dir}

mkdir cnn-out-files

echo 
echo "RUNNING GLOBAL LOCALISATION ..."
echo 

number_of_stacks=$(ls cnn-recon-org-files-packages/*.nii* | wc -l)
stack_names=$(ls cnn-recon-org-files-packages/*.nii*)

${mirtk_path}/mirtk prepare-for-cnn cnn-recon-res-files cnn-recon-stack-files run.csv run-info-summary.csv ${res} ${number_of_stacks} $(echo $stack_names)  ${all_num_lab} 0 


main_dir=$(pwd)


PYTHONIOENCODING=utf-8 python ${segm_path}/run_cnn_loc.py ${segm_path}/ ${check_path_brain}/ ${main_dir}/ ${main_dir}/cnn-out-files/ run.csv ${res} ${all_num_lab}

# # TR17 --- temporary script exit
# exit
# # end TR17

#ls  ${main_dir}/cnn-out-files


out_mask_names=$(ls cnn-out-files/*seg_pr*.nii*)
out_stack_names=$(ls cnn-recon-stack-files/*.nii*)

IFS=$'\n' read -rd '' -a all_masks <<<"$out_mask_names"
IFS=$'\n' read -rd '' -a all_stacks <<<"$out_stack_names"


echo 
echo "RUNNING CROPPED REFINEMENT ..."
echo 


mkdir cropped-files
mkdir cropped-cnn-out-files


for ((i=0;i<${#all_stacks[@]};i++));
do

	${mirtk_path}/mirtk dilate-image cnn-out-files/*-${i}_seg_pr*.nii* dl-m.nii.gz -iterations 6 

	${mirtk_path}/mirtk crop_volume cnn-recon-stack-files/stack-${i}.nii.gz dl-m.nii.gz cropped-files/cropped-stack-${i}.nii.gz 

done


number_of_stacks=$(ls cropped-files/*.nii* | wc -l)
stack_names=$(ls cropped-files/*.nii*)

${mirtk_path}/mirtk prepare-for-cnn cropped-cnn-recon-res-files cropped-cnn-recon-stack-files cropped-run.csv cropped-run-info-summary.csv ${res} ${number_of_stacks} $(echo $stack_names)  ${all_num_lab} 0 



PYTHONIOENCODING=utf-8 python ${segm_path}/run_cnn_loc.py ${segm_path}/ ${check_path_brain_cropped}/ ${main_dir}/ ${main_dir}/cropped-cnn-out-files/ cropped-run.csv ${res} ${all_num_lab}



echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo
echo "EXTRACTING ROI-SPECIFIC MASKS ..."
echo


cd ${main_dir}

out_mask_names=$(ls cropped-cnn-out-files/*seg_pr*.nii*)
out_stack_names=$(ls cnn-recon-stack-files/*.nii*)

IFS=$'\n' read -rd '' -a all_masks <<<"$out_mask_names"
IFS=$'\n' read -rd '' -a all_stacks <<<"$out_stack_names"


for ((j=0;j<${#roi_ids[@]};j++));
do

	cd ${main_dir}

	mkdir cnn-recon-mask-files-${roi_ids[j]}

	echo 


	echo "ROI : " ${roi_names[j]} " ... "
	echo
	current_lab=${roi_ids[j]}


	for ((i=0;i<${#all_masks[@]};i++));
	do


	    ${mirtk_path}/mirtk transform-image cropped-cnn-out-files/*-${i}_seg_pr*.nii* cnn-recon-mask-files-${roi_ids[j]}/mask-${i}.nii.gz -target cnn-recon-stack-files/stack-${i}.nii.gz -interp NN

	    ${mirtk_path}/mirtk extract-label cnn-recon-mask-files-${roi_ids[j]}/mask-${i}.nii.gz cnn-recon-mask-files-${roi_ids[j]}/mask-${i}.nii.gz ${current_lab} ${current_lab}

	    ${mirtk_path}/mirtk extract-connected-components cnn-recon-mask-files-${roi_ids[j]}/mask-${i}.nii.gz cnn-recon-mask-files-${roi_ids[j]}/mask-${i}.nii.gz


	   echo cnn-recon-stack-files/stack-${i}.nii.gz " - " cropped-cnn-out-files/*-${i}_seg_pr*.nii* " - " cnn-recon-mask-files-${roi_ids[j]}/mask-${i}.nii.gz


	done

done 



echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo
echo "RUNNING RECONSTRUCTION ..."
echo


cd ${main_dir}

for ((j=0;j<${#roi_ids[@]};j++));
do

	echo "ROI : " ${roi_names[j]} " ... "
	echo


	test_dir=out-proc-${roi_names[j]}
	if [[ -d ${test_dir} ]];then
		rm -r out-proc-${roi_names[j]}
	fi

	mkdir out-proc-${roi_names[j]}
	cd out-proc-${roi_names[j]}

	number_of_stacks=$(ls ../cnn-recon-stack-files/*.nii* | wc -l)
	stack_names=$(ls ../cnn-recon-stack-files/*.nii*)
	mask_names=$(ls ../cnn-recon-mask-files-${roi_ids[j]}/*.nii*)


	${mirtk_path}/mirtk reconstruct ${main_dir}/${roi_recon[j]}-output.nii.gz ${number_of_stacks} $(echo $stack_names) -masks $(echo $mask_names) -default_thickness ${default_thickness} -remote -iterations 3 -resolution ${output_resolution}



	test_file=${main_dir}/${roi_recon[j]}-output.nii.gz
	if [[ -f ${test_file} ]];then

		echo "Reconstruction was successful: " ${roi_recon[j]}-output.nii.gz

	else 

		echo "Reconstruction failed ... " 

	fi
	

done



echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo





