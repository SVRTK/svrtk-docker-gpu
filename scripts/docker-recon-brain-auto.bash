#!/bin/bash


echo
echo "-----------------------------------------------------------------------------"
echo "RUNNING AUTOMATED SVR RECONSTRUCTION"
echo "-----------------------------------------------------------------------------"
echo


default_recon_dir=$1


# Paths
mirtk_path=/home/MIRTK/build/bin
segm_path=/home/Segmentation_FetalMRI
template_path=/home/Segmentation_FetalMRI/reference-templates
check_path_brain=/home/Segmentation_FetalMRI/trained-models/checkpoints-brain-loc-labels
check_path_brain_cropped=/home/Segmentation_FetalMRI/trained-models/checkpoints-brain-loc-labels-cropped
check_path_roi_reo_4lab=/home/Segmentation_FetalMRI/trained-models/checkpoints-brain-reorientation



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
	
	
 
     echo
     echo "-----------------------------------------------------------------------------"
     echo
     
    
     
     echo
     echo "RUNNING REORIENTATION ..."
     echo

     cd ${main_dir}

     reo_roi_ids=(1 2 3 4)
     lab_start=(1 2 1 4)
     lab_stop=(1 2 4 4)
     lab_cc=(2 2 1 1)

     # 1 - front WM, 2 - back WM, 3 - bet, 4 - cerebellum

     mkdir dofs-to-atl
     mkdir in-recon-file
	 mkdir final-reo-mask-files
     
     cp ${main_dir}/${roi_recon[j]}-output.nii.gz in-recon-file

     res=128
     all_num_lab=4
     cnn_out_mode=1234
     ${mirtk_path}/mirtk prepare-for-cnn recon-res-files recon-stack-files run.csv run-info-summary.csv ${res} 1 in-recon-file/*nii*  ${all_num_lab} 0
     mkdir ${main_dir}/reo-${cnn_out_mode}-cnn-out-files
     rm ${main_dir}/reo-${cnn_out_mode}-cnn-out-files/*
	 PYTHONIOENCODING=utf-8 python ${segm_path}/run_cnn_loc.py ${segm_path}/ ${check_path_roi_reo_4lab} ${main_dir}/ ${main_dir}/reo-${cnn_out_mode}-cnn-out-files/ run.csv ${res} ${all_num_lab}

    jj=1000

    for ((w=0;w<${#reo_roi_ids[@]};w++));
    do
        current_lab=${reo_roi_ids[$w]}
        s1=${lab_start[$w]}
        s2=${lab_stop[$w]}
        currenct_cc=${lab_cc[$w]}
        ${mirtk_path}/mirtk extract-label ${main_dir}/reo-${cnn_out_mode}-cnn-out-files/*-${jj}_seg_pr*.nii* tmp-org-m.nii.gz ${s1} ${s2}
        ${mirtk_path}/mirtk extract-connected-components tmp-org-m.nii.gz tmp-org-m.nii.gz -n ${currenct_cc}
        cp tmp-org-m.nii.gz final-reo-mask-files/mask-${jj}-${current_lab}.nii.gz

    done


    ${mirtk_path}/mirtk init-dof init.dof

    z1=1
    z2=2
    z3=3
    z4=4

    ${mirtk_path}/mirtk register_landmarks ${template_path}/brain-ref-atlas-2021/new-brain-templ.nii.gz final-reo-mask-files/mask-${jj}-0.nii.gz  init.dof dofs-to-atl/dof-to-atl-${jj}.dof 4 4 ${template_path}/brain-ref-atlas-2021/mask-${z1}.nii.gz ${template_path}/brain-ref-atlas-2021/mask-${z2}.nii.gz ${template_path}/brain-ref-atlas-2021/mask-${z3}.nii.gz ${template_path}/brain-ref-atlas-2021/mask-${z4}.nii.gz final-reo-mask-files/mask-${jj}-${z1}.nii.gz final-reo-mask-files/mask-${jj}-${z2}.nii.gz final-reo-mask-files/mask-${jj}-${z3}.nii.gz final-reo-mask-files/mask-${jj}-${z4}.nii.gz


     ${mirtk_path}/mirtk transform-image ${main_dir}/${roi_recon[j]}-output.nii.gz ${main_dir}/reo-${roi_recon[j]}-output.nii.gz -dofin dofs-to-atl/dof-to-atl-${jj}.dof -target ${template_path}/brain-ref-atlas-2021/ref-space-brain.nii.gz -interp BSpline

     ${mirtk_path}/mirtk crop_volume ${main_dir}/reo-${roi_recon[j]}-output.nii.gz ${main_dir}/reo-${roi_recon[j]}-output.nii.gz ${main_dir}/reo-${roi_recon[j]}-output.nii.gz


     echo
     echo "-----------------------------------------------------------------------------"
     echo
 
 
	test_file=${main_dir}/reo-${roi_recon[j]}-output.nii.gz
	if [[ -f ${test_file} ]];then

		# TAR - pad to cuboid for Philips import
		cp ${main_dir}/reo-${roi_recon[j]}-output.nii.gz ${main_dir}/reo-${roi_recon[j]}-output-withoutPadding.nii.gz
		${mirtk_path}/mirtk resample-image ${main_dir}/reo-${roi_recon[j]}-output.nii.gz ${main_dir}/reo-${roi_recon[j]}-output.nii.gz -imsize 180 180 180
		
		# TAR - rename files
		mv ${main_dir}/${roi_recon[j]}-output.nii.gz ${roi_recon[j]}-output-withoutReorientation.nii.gz
		cp ${main_dir}/reo-${roi_recon[j]}-output.nii.gz ${main_dir}/${roi_recon[j]}-output.nii.gz
		
		echo "Reconstruction was successful: " ${roi_recon[j]}-output.nii.gz

	else 

		echo "Reconstruction failed ... " 

	fi
	

done


echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo
