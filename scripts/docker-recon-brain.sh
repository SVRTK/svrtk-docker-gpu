#!/bin/bash


echo
echo "-----------------------------------------------------------------------------"
echo "RUNNING AUTOMATED SVR RECONSTRCTION"
echo "-----------------------------------------------------------------------------"
echo


default_recon_dir=$1


# Paths
mirtk_path=/home/MIRTK/build/bin
segm_path=/home/Segmentation_FetalMRI
check_path_brain=/home/Segmentation_FetalMRI/trained-models/checkpoints-brain-loc-labels
check_path_brain_cropped=/home/Segmentation_FetalMRI/trained-models/checkpoints-brain-loc-labels-cropped


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

${mirtk_path}/mirtk prepare-for-cnn cnn-recon-res-files stack-files run.csv run-info-summary.csv ${res} ${number_of_stacks} $(echo $stack_names)  ${all_num_lab} 0 


main_dir=$(pwd)



PYTHONIOENCODING=utf-8 python ${segm_path}/run_cnn_loc.py ${segm_path}/ ${check_path_brain}/ ${main_dir}/ ${main_dir}/cnn-out-files/ run.csv ${res} ${all_num_lab}



#ls  ${main_dir}/cnn-out-files


out_mask_names=$(ls cnn-out-files/*seg_pr*.nii*)
out_stack_names=$(ls stack-files/*.nii*)

IFS=$'\n' read -rd '' -a all_masks <<<"$out_mask_names"
IFS=$'\n' read -rd '' -a all_stacks <<<"$out_stack_names"


echo 
echo "RUNNING CROPPED REFINEMENT ..."
echo 


mkdir cropped-files
mkdir cropped-cnn-out-files

mkdir tmp-masks-global


for ((i=0;i<${#all_stacks[@]};i++));
do

	jj=$((${i}+1000))

	echo ${jj} " ... "

	${mirtk_path}/mirtk extract-label cnn-out-files/*-${jj}_seg_pr*.nii* tmp-org-m.nii.gz 1 1  

	${mirtk_path}/mirtk extract-connected-components tmp-org-m.nii.gz tmp-org-m.nii.gz -max-size 950000

	cp tmp-org-m.nii.gz  tmp-masks-global/mask-${jj}.nii.gz

	${mirtk_path}/mirtk dilate-image tmp-org-m.nii.gz  dl-m.nii.gz -iterations 6 

	${mirtk_path}/mirtk crop_volume stack-files/stack-${jj}.nii.gz dl-m.nii.gz cropped-files/cropped-stack-${jj}.nii.gz 


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
out_stack_names=$(ls stack-files/*.nii*)

IFS=$'\n' read -rd '' -a all_masks <<<"$out_mask_names"
IFS=$'\n' read -rd '' -a all_stacks <<<"$out_stack_names"


for ((j=0;j<${#roi_ids[@]};j++));
do

	cd ${main_dir}

	mkdir mask-files-${roi_ids[j]}

	echo 


	echo "ROI : " ${roi_names[j]} " ... "
	echo
	current_lab=${roi_ids[j]}


	for ((i=0;i<${#all_masks[@]};i++));
	do

	    jj=$((${i}+1000))
																																								

	    #${mirtk_path}/mirtk transform-image cropped-cnn-out-files/*-${jj}_seg_pr*.nii* mask-files-${roi_ids[j]}/mask-${jj}.nii.gz -target stack-files/stack-${jj}.nii.gz -interp NN

	    ${mirtk_path}/mirtk transform-image cropped-cnn-out-files/*-${jj}_seg_pr*.nii* mask-files-${roi_ids[j]}/mask-${jj}.nii.gz -target cropped-files/*-${jj}.nii.gz -interp NN																																			  

	    ${mirtk_path}/mirtk extract-label mask-files-${roi_ids[j]}/mask-${jj}.nii.gz mask-files-${roi_ids[j]}/mask-${jj}.nii.gz ${current_lab} ${current_lab}

	    ${mirtk_path}/mirtk extract-connected-components mask-files-${roi_ids[j]}/mask-${jj}.nii.gz mask-files-${roi_ids[j]}/mask-${jj}.nii.gz -max-size 604000


	   echo stack-files/stack-${jj}.nii.gz " - " cropped-cnn-out-files/*-${jj}_seg_pr*.nii* " - " mask-files-${roi_ids[j]}/mask-${jj}.nii.gz


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



	number_of_stacks=$(ls ../cropped-files/*.nii* | wc -l)
	stack_names=$(ls ../cropped-files/*.nii*)
	mask_names=$(ls ../mask-files-${roi_ids[j]}/*.nii*)

	

	mkdir proc-stacks
	${mirtk_path}/mirtk stacks-and-masks-selection ${number_of_stacks} $(echo $stack_names) $(echo $mask_names) proc-stacks 15 1


	${mirtk_path}/mirtk average-images zz.nii.gz proc-stacks/*nii* 
	${mirtk_path}/mirtk resample-image zz.nii.gz zz.nii.gz -size 1 1 1
	${mirtk_path}/mirtk average-images zz.nii.gz proc-stacks/*nii* -target zz.nii.gz  
	${mirtk_path}/mirtk transform-image average_mask_cnn.nii.gz average_mask_cnn.nii.gz -target zz.nii.gz -interp NN 
	${mirtk_path}/mirtk transform-image selected_template.nii.gz selected_template.nii.gz -target zz.nii.gz 

	cp zz.nii.gz selected_template.nii.gz 


	${mirtk_path}/mirtk erode-image average_mask_cnn.nii.gz average_mask_cnn.nii.gz


	nStacks=$(ls proc-stacks/*.nii* | wc -l)



	${mirtk_path}/mirtk reconstruct ${main_dir}/${roi_recon[j]}-output.nii.gz  ${nStacks} proc-stacks/*.nii* -mask average_mask_cnn.nii.gz -template selected_template.nii.gz -default_thickness ${default_thickness} -svr_only -remote -iterations 3 -structural -resolution ${output_resolution}
	
	
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
