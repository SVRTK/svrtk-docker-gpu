#!/bin/bash


##########################################################################################################################
###### SCRIPT FOR AUTOMATED SVR RECONSTRUCTION (incl. optional GPU-acceleration): docker-recon-brain-auto.bash
###### King's College London 2021
###### https://github.com/SVRTK/svrtk-docker-gpu
##########################################################################################################################

echo
echo "-----------------------------------------------------------------------------"
echo "RUNNING AUTOMATED SVR RECONSTRUCTION"
echo "-----------------------------------------------------------------------------"
echo

##########################################################################################################################
###### INPUTS
##########################################################################################################################

#folder with input files
default_recon_dir=$1

#cnn mode: -1 cpu, 1 gpu
cnn_mode=$2

#severity of motion mode: -1 minor, 1 severe
motion_correction_mode=$3


source ~/.bashrc
cd ${default_recon_dir}

##########################################################################################################################
###### DEFAULT PARAMETERS AND PATHS
##########################################################################################################################

# software and network weight paths
mirtk_path=/home/MIRTK/build/bin
segm_path=/home/Segmentation_FetalMRI
template_path=/home/Segmentation_FetalMRI/reference-templates
check_path_brain=/home/Segmentation_FetalMRI/trained-models/checkpoints-brain-loc-labels
check_path_brain_cropped=/home/Segmentation_FetalMRI/trained-models/checkpoints-brain-loc-labels-cropped
check_path_roi_reo_4lab=/home/Segmentation_FetalMRI/trained-models/checkpoints-brain-reorientation
check_path_roi_reo_4lab_stacks=/home/Segmentation_FetalMRI/trained-models/checkpoints-brain-reorientation-stacks

# CNN parameters
res=128
all_num_lab=1
all_num_lab_reo=4
current_lab=1

# NOTE: 1 package is acceptable for low motion datasets / -1 for severe cases for automated detection
if [ $motion_correction_mode -gt 0 ]; then
    num_packages=-1
else
    num_packages=1
fi

# TODO: implement check in case slice thickness inconsistent across stacks
if [[ -f "${default_recon_dir}/log_slice_thickness.txt" ]]; then
    default_thickness=`cat "${default_recon_dir}/log_slice_thickness.txt" | awk -F' ' '{print $1}'`
else
    echo "WARNING: Setting default_thickness = 2.5"
    default_thickness=2.5
fi
echo

# NOTE: change output resolution to 0.75 - 0.8 ?
output_resolution=0.85

# Reconstruction ROI names
roi_recon=("SVR")
roi_names=("brain")
roi_ids=(1)
selected_recon_roi=0
selected_recon_roi=0

##########################################################################################################################
###### COPY INPUT .NII FILES TO THE PROCESSING FOLDER
##########################################################################################################################

# navigate to the processing folder and remove any files left from previous processing sessions
test_dir=${default_recon_dir}/svr_processing_files
if [[ -d ${test_dir} ]];then
rm -r ${default_recon_dir}/svr_processing_files/*
else
mkdir ${default_recon_dir}/svr_processing_files
fi

test_file=${default_recon_dir}/error.txt
if [[ -f ${test_file} ]];then
rm ${default_recon_dir}/error.txt
fi

test_file=${default_recon_dir}/SVR-output.nii.gz
if [[ -f ${test_file} ]];then
rm ${default_recon_dir}/SVR-output*
fi

# check the total number of available .nii files
num_stacks=$(find . -name "*.nii*" | wc -l)
if [ $num_stacks -gt 1 ]; then
    echo " - found " ${num_stacks} ".nii files"
else
    echo
    echo "-----------------------------------------------------------------------------"
    echo "ERROR : NO .NII FILES FOUND - EXIT ..."
    echo "-----------------------------------------------------------------------------"
    echo
    echo "ERROR: NO INPUT FILLES. " > ${default_recon_dir}/error.txt
    exit
fi

main_dir=${default_recon_dir}/svr_processing_files
mkdir ${default_recon_dir}/svr_processing_files/cnn-recon-org-files
#find ${default_recon_dir}/ -name "*.nii*" -exec cp {} ${main_dir}/cnn-recon-org-files \;
cp ${default_recon_dir}/*.nii* ${main_dir}/cnn-recon-org-files/
cd ${default_recon_dir}/svr_processing_files


mkdir cnn-recon-org-files-packages
cp cnn-recon-org-files/* cnn-recon-org-files-packages

# split into packages only if the default parameter number is not 1
if [ $num_packages -ne 1 ]; then
    echo
    echo "-----------------------------------------------------------------------------"
    echo "SPLITTING INTO PACKAGES ..."
    echo "-----------------------------------------------------------------------------"
    echo

    cd ${main_dir}
    cd cnn-recon-org-files-packages

    stack_names=$(ls *.nii*)
    IFS=$'\n' read -rd '' -a all_stacks <<<"$stack_names"

    echo "folder : " ${in_file_dir}
    for ((i=0;i<${#all_stacks[@]};i++));
    do
        ${mirtk_path}/mirtk extract-packages ${all_stacks[$i]} ${num_packages}
        rm ${all_stacks[$i]}
        rm package-template.nii.gz
        echo " - " ${all_stacks[$i]}
    done
fi

#final input files
cd ${main_dir}
stack_names=$(ls cnn-recon-org-files-packages/*.nii*)
IFS=$'\n' read -rd '' -a all_stacks <<<"$stack_names"

##########################################################################################################################
###### 3D UNET-BASED GLOBAL BRAIN LOCALISATION + LOCAL MASK REFINEMENT + REORIENTATION (FOR SEVERE MOTION CASES)
##########################################################################################################################

echo
echo "-----------------------------------------------------------------------------"
echo "3D UNET SEGMENTATION ..."
echo "-----------------------------------------------------------------------------"
echo

cd ${main_dir}
mkdir cnn-out-files

echo
echo "RUNNING GLOBAL LOCALISATION ..."
echo

# 3D UNet global localisaton of the brain in the original stacks/packages
number_of_stacks=$(ls cnn-recon-org-files-packages/*.nii* | wc -l)
stack_names=$(ls cnn-recon-org-files-packages/*.nii*)
all_num_lab=1
${mirtk_path}/mirtk prepare-for-cnn cnn-recon-res-files stack-files run.csv run-info-summary.csv ${res} ${number_of_stacks} $(echo $stack_names)  ${all_num_lab} 0
main_dir=$(pwd)
PYTHONIOENCODING=utf-8 python ${segm_path}/run_cnn_loc_gpu_cpu.py ${segm_path}/ ${check_path_brain}/ ${main_dir}/ ${main_dir}/cnn-out-files/ run.csv ${res} ${all_num_lab} ${cnn_mode}
out_mask_names=$(ls cnn-out-files/*seg_pr*.nii*)
out_stack_names=$(ls stack-files/*.nii*)
IFS=$'\n' read -rd '' -a all_masks <<<"$out_mask_names"
IFS=$'\n' read -rd '' -a all_stacks <<<"$out_stack_names"

test_file=cnn-out-files/cnn-recon-res-files_in-res-stack-1000_img-0.nii.gz
if [[ ! -f ${test_file} ]];then
    echo
    echo "-----------------------------------------------------------------------------"
    echo "ERROR : GLOBAL 3D UNET LOCALISATION FAILED ..."
    echo "-----------------------------------------------------------------------------"
    echo
    echo "ERROR : GLOBAL 3D UNET LOCALISATION FAILED. " > ${default_recon_dir}/error.txt
    exit
fi

echo
echo "RUNNING CROPPED REFINEMENT ..."
echo

mkdir cropped-files
mkdir cropped-cnn-out-files
mkdir tmp-masks-global

# cropping all stacks based on the global brain ROI masks
for ((i=0;i<${#all_stacks[@]};i++));
do
    jj=$((${i}+1000))
    ${mirtk_path}/mirtk extract-label cnn-out-files/*-${jj}_seg_pr*.nii* tmp-org-m.nii.gz 1 1
    ${mirtk_path}/mirtk extract-connected-components tmp-org-m.nii.gz tmp-org-m.nii.gz -max-size 1000000
    ${mirtk_path}/mirtk dilate-image tmp-org-m.nii.gz  dl-m.nii.gz -iterations 6
    ${mirtk_path}/mirtk crop_volume stack-files/stack-${jj}.nii.gz dl-m.nii.gz cropped-files/cropped-stack-${jj}.nii.gz
done

# 3D UNet segmentation of the brain in the cropped stacks
number_of_stacks=$(ls cropped-files/*.nii* | wc -l)
stack_names=$(ls cropped-files/*.nii*)
all_num_lab=1
${mirtk_path}/mirtk prepare-for-cnn cropped-cnn-recon-res-files cropped-cnn-recon-stack-files cropped-run.csv cropped-run-info-summary.csv ${res} ${number_of_stacks} $(echo $stack_names) ${all_num_lab} 0
PYTHONIOENCODING=utf-8 python ${segm_path}/run_cnn_loc_gpu_cpu.py ${segm_path}/ ${check_path_brain_cropped}/ ${main_dir}/ ${main_dir}/cropped-cnn-out-files/ cropped-run.csv ${res} ${all_num_lab} ${cnn_mode}

test_file=cropped-cnn-out-files/cropped-cnn-recon-res-files_in-res-stack-1000_img-0.nii.gz
if [[ ! -f ${test_file} ]];then
    echo
    echo "-----------------------------------------------------------------------------"
    echo "ERROR : CROPPED 3D UNET LOCALISATION FAILED ..."
    echo "-----------------------------------------------------------------------------"
    echo
    echo "ERROR : CROPPED 3D UNET LOCALISATION FAILED. " > ${default_recon_dir}/error.txt
    exit
fi

echo
echo "EXTRACTING ROI-SPECIFIC MASKS ..."
echo

cd ${main_dir}
out_mask_names=$(ls cropped-cnn-out-files/*seg_pr*.nii*)
out_stack_names=$(ls stack-files/*.nii*)
IFS=$'\n' read -rd '' -a all_masks <<<"$out_mask_names"
IFS=$'\n' read -rd '' -a all_stacks <<<"$out_stack_names"

cd ${main_dir}

mkdir mask-files-${roi_ids[${selected_recon_roi}]}
current_lab=1

for ((i=0;i<${#all_masks[@]};i++));
do
    jj=$((${i}+1000))
    # extraction of brain masks
    ${mirtk_path}/mirtk transform-image cropped-cnn-out-files/*-${jj}_seg_pr*.nii* mask-files-${roi_ids[${selected_recon_roi}]}/mask-${jj}.nii.gz -target cropped-files/*-${jj}.nii.gz -interp NN
    ${mirtk_path}/mirtk extract-label mask-files-${roi_ids[${selected_recon_roi}]}/mask-${jj}.nii.gz mask-files-${roi_ids[${selected_recon_roi}]}/mask-${jj}.nii.gz ${current_lab} ${current_lab}
    ${mirtk_path}/mirtk extract-connected-components mask-files-${roi_ids[${selected_recon_roi}]}/mask-${jj}.nii.gz mask-files-${roi_ids[${selected_recon_roi}]}/mask-${jj}.nii.gz -max-size 800000

    # centering stacks vs. brain centre for severe motion cases
    #if [ $motion_correction_mode -gt 0 ]; then
    
    ${mirtk_path}/mirtk transform-image mask-files-${roi_ids[$selected_recon_roi]}/mask-${jj}.nii.gz mask-files-${roi_ids[$selected_recon_roi]}/mask-${jj}.nii.gz -target  cropped-files/cropped-stack-${jj}.nii.gz -interp NN
    ${mirtk_path}/mirtk centre_volume cropped-files/cropped-stack-${jj}.nii.gz mask-files-${roi_ids[$selected_recon_roi]}/mask-${jj}.nii.gz cropped-files/cropped-stack-${jj}.nii.gz
    ${mirtk_path}/mirtk centre_volume mask-files-${roi_ids[$selected_recon_roi]}/mask-${jj}.nii.gz mask-files-${roi_ids[$selected_recon_roi]}/mask-${jj}.nii.gz mask-files-${roi_ids[$selected_recon_roi]}/mask-${jj}.nii.gz
    
    #fi

    echo stack-files/stack-${jj}.nii.gz " - " cropped-cnn-out-files/*-${jj}_seg_pr*.nii* " - " mask-files-${roi_ids[${selected_recon_roi}]}/mask-${jj}.nii.gz
done

## CNN landmark-based reorientation of stacks to the standard space for severe motion cases (default now)
#if [ $motion_correction_mode -gt 0 ]; then

    mkdir cropped-cnn-out-files-4reo
    mkdir stack-dofs-to-atl
    mkdir stack-reo-mask-files

    number_of_stacks=$(ls cropped-files/*.nii* | wc -l)
    stack_names=$(ls cropped-files/*.nii*)

    # 3D UNet segmentation of 4 brain landmark labels
    all_num_lab_reo=4
    ${mirtk_path}/mirtk prepare-for-cnn cropped-res-files cropped-stack-files cropped-run-4reo.csv cropped-run-info-summary.csv ${res} ${number_of_stacks} $(echo $stack_names) ${all_num_lab_reo} 0
    PYTHONIOENCODING=utf-8 python ${segm_path}/run_cnn_loc_gpu_cpu.py ${segm_path}/ ${check_path_roi_reo_4lab_stacks}/ ${main_dir}/ ${main_dir}/cropped-cnn-out-files-4reo/ cropped-run-4reo.csv ${res} ${all_num_lab_reo} ${cnn_mode}

    reo_roi_ids=(1 2 3 4)
    lab_start=(1 2 1 4)
    lab_stop=(1 2 4 4)
    lab_cc=(2 2 1 1)

    # 1 - front WM, 2 - back WM, 3 - bet, 4 - cerebellum
    test_file=cropped-cnn-out-files-4reo/cropped-res-files_in-res-stack-1000_img-0.nii.gz
    if [[ ! -f ${test_file} ]];then
        echo
        echo "-----------------------------------------------------------------------------"
        echo "ERROR : CROPPED 3D UNET REORIENTATION FAILED ..."
        echo "-----------------------------------------------------------------------------"
        echo
        echo "ERROR : CROPPED 3D UNET REORIENTATION FAILED. " > ${default_recon_dir}/error.txt
        exit
    fi

    out_mask_names=$(ls cropped-cnn-out-files-4reo/*seg_pr*.nii*)
    IFS=$'\n' read -rd '' -a all_masks <<<"$out_mask_names"

    for ((i=0;i<${#all_masks[@]};i++));
    do

        jj=$((${i}+1000))
        echo " - " ${jj} " ... "

        # extracting landmark masks
        for ((w=0;w<${#reo_roi_ids[@]};w++));
        do
            current_lab=${reo_roi_ids[$w]}
            s1=${lab_start[$w]}
            s2=${lab_stop[$w]}
            currenct_cc=${lab_cc[$w]}
            ${mirtk_path}/mirtk extract-label ${main_dir}/cropped-cnn-out-files-4reo/*-${jj}_seg_pr*.nii* tmp-org-m.nii.gz ${s1} ${s2}
            ${mirtk_path}/mirtk extract-connected-components tmp-org-m.nii.gz tmp-org-m.nii.gz -n ${currenct_cc}
            cp tmp-org-m.nii.gz stack-reo-mask-files/mask-${jj}-${current_lab}.nii.gz
        done

        ${mirtk_path}/mirtk init-dof init.dof
        z1=1; z2=2; z3=3; z4=4 ;

        # running landmark-based reorientation
        ${mirtk_path}/mirtk register_landmarks ${template_path}/brain-ref-atlas-2021/new-brain-templ.nii.gz stack-reo-mask-files/mask-${jj}-0.nii.gz init.dof stack-dofs-to-atl/dof-to-atl-${jj}.dof 4 4 ${template_path}/brain-ref-atlas-2021/mask-${z1}.nii.gz ${template_path}/brain-ref-atlas-2021/mask-${z2}.nii.gz ${template_path}/brain-ref-atlas-2021/mask-${z3}.nii.gz ${template_path}/brain-ref-atlas-2021/mask-${z4}.nii.gz stack-reo-mask-files/mask-${jj}-${z1}.nii.gz stack-reo-mask-files/mask-${jj}-${z2}.nii.gz stack-reo-mask-files/mask-${jj}-${z3}.nii.gz stack-reo-mask-files/mask-${jj}-${z4}.nii.gz > tmp.txt

        # changing stack header orientation based on the transformations
        ${mirtk_path}/mirtk edit-image cropped-files/cropped-stack-${jj}.nii.gz cropped-files/cropped-stack-${jj}.nii.gz -dofin_i stack-dofs-to-atl/dof-to-atl-${jj}.dof
        ${mirtk_path}/mirtk edit-image mask-files-${roi_ids[$selected_recon_roi]}/mask-${jj}.nii.gz mask-files-${roi_ids[$selected_recon_roi]}/mask-${jj}.nii.gz -dofin_i stack-dofs-to-atl/dof-to-atl-${jj}.dof

    done

#fi

##########################################################################################################################
###### STACK SELECTION + SVR RECONSTRUCTION
##########################################################################################################################

echo
echo "-----------------------------------------------------------------------------"
echo "RUNNING STACK SELECTION ..."
echo "-----------------------------------------------------------------------------"
echo

cd ${main_dir}

mkdir out-proc-${roi_names[${selected_recon_roi}]}
cd out-proc-${roi_names[${selected_recon_roi}]}

number_of_stacks=$(ls ../cropped-files/*.nii* | wc -l)
stack_names=$(ls ../cropped-files/*.nii*)
mask_names=$(ls ../mask-files-${roi_ids[$selected_recon_roi]}/*.nii*)

# selection/exclusion of stacks based on similarity metrics and generation of the average mask
mkdir proc-stacks
${mirtk_path}/mirtk stacks-and-masks-selection ${number_of_stacks} $(echo $stack_names) $(echo $mask_names) proc-stacks 15 1

test_file=average_mask_cnn.nii.gz
if [[ ! -f ${test_file} ]];then
    echo
    echo "-----------------------------------------------------------------------------"
    echo "ERROR : STACK SELECTION FAILED ..."
    echo "-----------------------------------------------------------------------------"
    echo
    echo "ERROR: STACK SELECTION FAILED. " > ${default_recon_dir}/error.txt
    exit
fi

# generation of the average template
${mirtk_path}/mirtk average-images average_volume.nii.gz proc-stacks/*nii*
${mirtk_path}/mirtk resample-image average_volume.nii.gz average_volume.nii.gz -size 1 1 1
${mirtk_path}/mirtk average-images average_volume.nii.gz proc-stacks/*nii* -target average_volume.nii.gz
${mirtk_path}/mirtk transform-image average_mask_cnn.nii.gz average_mask_cnn.nii.gz -target average_volume.nii.gz -interp NN
${mirtk_path}/mirtk erode-image average_mask_cnn.nii.gz average_mask_cnn.nii.gz

echo
echo "-----------------------------------------------------------------------------"
echo "RUNNING RECONSTRUCTION ..."
echo "-----------------------------------------------------------------------------"
echo

# SVR reconstruction
nStacks=$(ls proc-stacks/*.nii* | wc -l)
${mirtk_path}/mirtk reconstruct ${main_dir}/${roi_recon[${selected_recon_roi}]}-output.nii.gz  ${nStacks} proc-stacks/*.nii* -mask average_mask_cnn.nii.gz -template average_volume.nii.gz -default_thickness ${default_thickness} -svr_only -iterations 3 -structural -resolution ${output_resolution}

test_file=${main_dir}/${roi_recon[${selected_recon_roi}]}-output.nii.gz
if [[ ! -f ${test_file} ]];then
    echo
    echo "-----------------------------------------------------------------------------"
    echo "ERROR : SVR RECONSTRUCTION FAILED ..."
    echo "-----------------------------------------------------------------------------"
    echo
    echo "ERROR: SVR RECONSTRUCTION FAILED. " > ${default_recon_dir}/error.txt
    exit
fi

##########################################################################################################################
###### CNN-BASED REORIENTATION
##########################################################################################################################

echo
echo "-----------------------------------------------------------------------------"
echo "RUNNING LANDMARK-BASED REORIENTATION ..."
echo "-----------------------------------------------------------------------------"
echo

cd ${main_dir}

# 1 - front WM, 2 - back WM, 3 - bet, 4 - cerebellum
reo_roi_ids=(1 2 3 4); lab_start=(1 2 1 4); lab_stop=(1 2 4 4); lab_cc=(2 2 1 1);

mkdir dofs-to-atl
mkdir in-recon-file
mkdir final-reo-mask-files

cp ${main_dir}/${roi_recon[${selected_recon_roi}]}-output.nii.gz in-recon-file

# 3D UNet 4 landmark label localisation for the reconstructed image
res=128
all_num_lab_reo=4
cnn_out_mode=1234
${mirtk_path}/mirtk prepare-for-cnn recon-res-files recon-stack-files run.csv run-info-summary.csv ${res} 1 in-recon-file/*nii*  ${all_num_lab_reo} 0
mkdir ${main_dir}/reo-${cnn_out_mode}-cnn-out-files
PYTHONIOENCODING=utf-8 python ${segm_path}/run_cnn_loc_gpu_cpu.py ${segm_path}/ ${check_path_roi_reo_4lab} ${main_dir}/ ${main_dir}/reo-${cnn_out_mode}-cnn-out-files/ run.csv ${res} ${all_num_lab_reo} ${cnn_mode}

test_file=${main_dir}/reo-${cnn_out_mode}-cnn-out-files/recon-res-files_in-res-stack-1000_img-0.nii.gz
if [[ ! -f ${test_file} ]];then
    echo
    echo "-----------------------------------------------------------------------------"
    echo "ERROR : 3D UNET REORIENTATION OF THE SVR-RECONSTRUCTED IMAGE FAILED ..."
    echo "-----------------------------------------------------------------------------"
    echo
    echo "ERROR : 3D UNET REORIENTATION OF THE SVR-RECONSTRUCTED IMAGE FAILED. " > ${default_recon_dir}/error.txt
    exit
fi

# extration of landmark labels
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
z1=1; z2=2; z3=3; z4=4;

# landmark-based registration to the atlas space
${mirtk_path}/mirtk register_landmarks ${template_path}/brain-ref-atlas-2021/new-brain-templ.nii.gz final-reo-mask-files/mask-${jj}-0.nii.gz  init.dof dofs-to-atl/dof-to-atl-${jj}.dof 4 4 ${template_path}/brain-ref-atlas-2021/mask-${z1}.nii.gz ${template_path}/brain-ref-atlas-2021/mask-${z2}.nii.gz ${template_path}/brain-ref-atlas-2021/mask-${z3}.nii.gz ${template_path}/brain-ref-atlas-2021/mask-${z4}.nii.gz final-reo-mask-files/mask-${jj}-${z1}.nii.gz final-reo-mask-files/mask-${jj}-${z2}.nii.gz final-reo-mask-files/mask-${jj}-${z3}.nii.gz final-reo-mask-files/mask-${jj}-${z4}.nii.gz > tmp.txt

# transformation to the atlas space
${mirtk_path}/mirtk transform-image ${main_dir}/${roi_recon[${selected_recon_roi}]}-output.nii.gz ${main_dir}/reo-${roi_recon[${selected_recon_roi}]}-output.nii.gz -dofin dofs-to-atl/dof-to-atl-${jj}.dof -target ${template_path}/brain-ref-atlas-2021/ref-space-brain.nii.gz -interp BSpline

# cropping any remaining black background
${mirtk_path}/mirtk crop_volume ${main_dir}/reo-${roi_recon[${selected_recon_roi}]}-output.nii.gz ${main_dir}/reo-${roi_recon[${selected_recon_roi}]}-output.nii.gz ${main_dir}/reo-${roi_recon[${selected_recon_roi}]}-output.nii.gz

echo
echo "-----------------------------------------------------------------------------"
echo "ADJUSTING & RENAMING FINAL FILES"
echo "-----------------------------------------------------------------------------"
echo

test_file=${main_dir}/reo-${roi_recon[${selected_recon_roi}]}-output.nii.gz
if [[ -f ${test_file} ]];then

    # TAR - rename files
    mv ${main_dir}/${roi_recon[${selected_recon_roi}]}-output.nii.gz ${main_dir}/${roi_recon[${selected_recon_roi}]}-output-withoutReorientation.nii.gz
    cp ${main_dir}/reo-${roi_recon[${selected_recon_roi}]}-output.nii.gz ${main_dir}/${roi_recon[${selected_recon_roi}]}-output.nii.gz

	# TAR - move final files to /recon dir
    cp ${main_dir}/${roi_recon[${selected_recon_roi}]}-output-withoutReorientation.nii.gz ${default_recon_dir}/${roi_recon[${selected_recon_roi}]}-output-withoutReorientation.nii.gz
    cp ${main_dir}/${roi_recon[${selected_recon_roi}]}-output.nii.gz ${default_recon_dir}/${roi_recon[${selected_recon_roi}]}-output.nii.gz

    echo "Reconstruction was successful: " ${default_recon_dir}/${roi_recon[${selected_recon_roi}]}-output.nii.gz

else
    echo "Reconstruction failed ... "
    echo "ERROR : RECONSTRUCTION PIPELINE FAILED (REORIENTATION OR SAVING STEP). " > ${default_recon_dir}/error.txt
fi



echo
echo "-----------------------------------------------------------------------------"
echo "-----------------------------------------------------------------------------"
echo


