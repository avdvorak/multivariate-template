#!/bin/bash


#####################################################################################	
# Script functions

# Create our "press_enter function"
function press_enter
{
    echo ""
    echo -n "Press Enter to continue"
    read
    clear
}

# Create a simple method for using comment blocks
[ -z $BASH ] || shopt -s expand_aliases
alias BCOMM="if [ ]; then"
alias ECOMM="fi"


if [ "$1" == "-h" ]; then
  echo "------------------------------------------------------------------------------------------------------------------------"
  echo "Pipeline for cord data: multivariate template creation with structural mFFE images, GRASE, and mcDESPOT"
  echo ""
  echo -e "Useage to detach and save output: $0 2>&1 | tee Output.txt"
  echo ""
  echo " Written by Adam Dvorak (09/2018) for"
  echo "        Myelin imaging in the central nervous system: Comparison of multi-echo T2 relaxation and steady-state approaches"
  echo ""
  echo "------------------------------------------------------------------------------------------------------------------------"
  exit 0
fi

# general
inputPath='/local/atlas/Adam/multivariate_MWF_MVF_Cord'
# Set the path to QC
qcPath=${inputPath}/QualityControl
# Set path for template to be created in
templatePath=${inputPath}/Template

subjects=' C001 C002 C003 C004 C005 C006 C007 C008 C009 C010 C011 C012 C013 C014 C015 C016 C017 C018 C019 C020 C021 C023 C024 C025 C026 C027 C028 C031 '
#####################################################################################


BCOMM
##################################################################################### Prep and register data
for subject in ${subjects}
do
	printf " \n STARTING ${subject} data prep! "

	############################################## Prep mFFE
	cd ${inputPath}/${subject}/mFFE

	# segment w CSF
	sct_propseg -i ${subject}_mFFE.nii.gz -c t2s -CSF -qc ${qcPath}

	# mask
	fsl5.0-fslmaths ${subject}_mFFE.nii.gz \
		-mas ${subject}_mFFE_seg.nii.gz \
		${subject}_mFFE_Masked.nii.gz


	############################################## Prep and register GRASE
	cd ${inputPath}/${subject}/GRASE

	# segment
	sct_propseg -i ${subject}_GRASE_Echo_16.nii.gz -c t2 -CSF -qc ${qcPath}

	# mask echo 1 with better segmentation from echo 16
	fsl5.0-fslmaths GRASE_Echo_1.nii.gz \
		-mas GRASE_Echo_16_seg.nii.gz \
		${subject}_GRASE_Echo_1_Masked.nii.gz

	# then register to mFFE with slicewise reg first aligning w segmentations then refining with cord images
	sct_register_multimodal -i ${subject}_GRASE_Echo_1.nii.gz \
		-iseg ${subject}_GRASE_Echo_16_seg.nii.gz \
		-d ${inputPath}/${subject}/mFFE/${subject}_mFFE.nii.gz \
		-dseg ${inputPath}/${subject}/mFFE/${subject}_mFFE_seg.nii.gz \
		-m ${inputPath}/${subject}/mFFE/${subject}_mFFE_seg.nii.gz \
		-param "step=1,type=seg,algo=centermass,slicewise=1:step=2,type=im,algo=rigid,metric=MI,iter=20,slicewise=1,init=geometric" \
		-o ${subject}_GRASE_Echo_1_Warped.nii.gz

	# mask warped GRASE w sharper mFFE cord seg
	fsl5.0-fslmaths ${subject}_GRASE_Echo_1_Warped.nii.gz \
		-mas ${inputPath}/${subject}/mFFE/${subject}_mFFE_seg.nii.gz \
		${subject}_GRASE_Echo_1_WarpedMasked.nii.gz

	############################################## Prep IRSPGR
	cd ${inputPath}/${subject}/mcDESPOT/

	# segment w CSF
	sct_propseg -i ${subject}_IRSPGR.nii.gz -c t1 -CSF -qc ${qcPath}

	# mask 
	fsl5.0-fslmaths ${subject}_IRSPGR.nii.gz \
		-mas ${subject}_IRSPGR_seg.nii.gz \
		${subject}_IRSPGR_Masked.nii.gz

	# then register to mFFE with slicewise reg first aligning w segmentations then refining with cord images
	sct_register_multimodal -i ${subject}_IRSPGR.nii.gz \
		-iseg ${subject}_IRSPGR_seg.nii.gz \
		-d ${inputPath}/${subject}/mFFE/${subject}_mFFE.nii.gz \
		-dseg ${inputPath}/${subject}/mFFE/${subject}_mFFE_seg.nii.gz \
		-m ${inputPath}/${subject}/mFFE/${subject}_mFFE_seg.nii.gz \
		-param "step=1,type=seg,algo=centermass,slicewise=1:step=2,type=im,algo=rigid,metric=MI,iter=20,slicewise=1,init=geometric" \
		-o ${subject}_IRSPGR_Warped.nii.gz


	# mask warped IRSPGR w sharper mFFE cord seg
	fsl5.0-fslmaths ${subject}_IRSPGR_Warped.nii.gz \
		-mas ${inputPath}/${subject}/mFFE/${subject}_mFFE_seg.nii.gz \
		${subject}_IRSPGR_WarpedMasked.nii.gz


	printf " \n COMPLETED ${subject} data prep! \n"
done
#####################################################################################
ECOMM


BCOMM
##################################################################################### Multivariate template creation
for subject in $subjects
do
  # make cp for template creation
  cp ${inputPath}/${subject}/mFFE/${subject}_mFFE_Masked.nii.gz ${templatePath}/${subject}_mFFE.nii.gz
  cp ${inputPath}/${subject}/GRASE/${subject}_GRASE_Echo_1_WarpedMasked.nii.gz ${templatePath}/${subject}_GRASE.nii.gz
  cp ${inputPath}/${subject}/mcDESPOT/${subject}_IRSPGR_WarpedMasked.nii.gz ${templatePath}/${subject}_IRSPGR.nii.gz
done

###############  MAKE TEMPLATE: With 3DT1 (brain extracted)
#                                and GRASE T1 replica (brain extracted)
#                                and with IRSPGR N4 corrected (brain extracted)

# Print date and time that template creation begins
printf " \n \n \n \n BEGINNING TEMPLATE CREATION \n \n \n \n "
date +"Date : %d/%m/%Y Time : %H.%M.%S"
printf "  \n \n \n \n "

cd ${templatePath}/

${ANTSPATH}/antsMultivariateTemplateConstruction2.sh \
  -d 3 \
  -o ${templatePath}/T_ \
  -i 4 \
  -g 0.2 \
  -c 2 \
  -j 18 \
  -k 3 \
  -w 1.0x0.5x0.5 \
  -f 6x4x2x1 \
  -s 3x2x1x0 \
  -q 140x100x80x20 \
  -n 0 \
  -y 1 \
  -r 1 \
  -m CC \
  -t SyN \
  templateInput.csv
###############

# Print date and time that template creation finishes
printf " \n \n \n \n COMPLETED TEMPLATE CREATION \n \n \n \n "
date +"Date : %d/%m/%Y Time : %H.%M.%S"
printf "  \n \n \n \n "
#####################################################################################
ECOMM



