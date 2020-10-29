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
  echo "Pipeline for brain data: multivariate template creation with structural 3DT1 images, GRASE, and mcDESPOT"
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
inputPath='/local/atlas/Adam/multivariate_MWF_MVF_Brain'
# Set the path to QC
qcPath=${inputPath}/QualityControl
# Set path for template to be created in
templatePath=${inputPath}/Template
# Set the path to OASIS template
oasisPath='/local/atlas/OASIS'

cores=24
subjects=' C001 C002 C003 C004 C005 C006 C007 C008 C009 C010 C011 C012 C013 C014 C015 C016 C017 C018 C019 C020 C021 C023 C024 C025 C026 C027 C028 C031 '
#####################################################################################

BCOMM
##################################################################################### Prep 3DT1
for subject in ${subjects} # For loop over subject specified above
do
  # Change into the subject folder
  cd ${inputPath}/${subject}/3DT1/


  # start the timer
  timer_start="$(date +"Date : %d/%m/%Y Time : %H.%M.%S")"
  printf " \n Beginning ${subject} 3DT1 Preparation at: \n ${timer_start} \n "

  # N4 correction
  N4BiasFieldCorrection \
    -d 3 \
    -i ${subject}_3DT1.nii.gz \
    -o ${subject}_3DT1_N4.nii.gz \
    -v 0
  printf " \n ${subject} N4 Correction Complete \n "


  # Brain extraction
  antsBrainExtraction.sh \
    -d 3 \
    -k 1 \
    -z 0 \
    -c 3x1x2x3 \
    -a ${subject}_3DT1_N4.nii.gz \
    -e ${oasisPath}/T_template0.nii.gz \
    -m ${oasisPath}/T_template0_BrainCerebellumProbabilityMask.nii.gz \
    -f ${oasisPath}/T_template0_BrainCerebellumRegistrationMask.nii.gz \
    -o ${inputPath}/${subject}/3DT1/${subject}_3DT1_N4

  printf " \n ${subject} Brain Extraction Complete \n "

  # Clean up extra output
  rm *Warp.* *Affine* *Tmp.* *0.*

  printf " \n Creating ${subject} Brain Extraction Quality Control Images "
  # create mask
  ThresholdImage 3 ${subject}_3DT1_N4BrainExtractionSegmentation.nii.gz segmentationMask.nii.gz 0 0 0 1
  # create RGB from segmentation
  ConvertScalarImageToRGB 3 ${subject}_3DT1_N4BrainExtractionSegmentation.nii.gz segmentationRgb.nii.gz none custom ${qcPath}/snapColormap.txt 0 6

  # create tiled mosaic in each orientation
  for dim in 0 1 2
  do
    printf " ${dim} \n "
    printf "${qcPath}/3DT1_BE/${subject}_${dim}.png "
    CreateTiledMosaic -i ${subject}_3DT1_N4.nii.gz -r segmentationRgb.nii.gz -o ${qcPath}/3DT1_BE/${subject}_${dim}.png -a 0.3 -t -1x-1 -p mask -s [3,mask,mask] -x segmentationMask.nii.gz -d ${dim}
  done

  # stop the timer
  timer_stop="$(date +"Date : %d/%m/%Y Time : %H.%M.%S")"
  printf " \n \n ${subject} 3DT1 Preparation Complete \n Started: \n ${timer_start} \n Finished: \n ${timer_stop} \n \n "

done
#####################################################################################
ECOMM

BCOMM
##################################################################################### Prep GRASE
for subject in ${subjects} # For loop over subject specified above
do
  # Change into the subject folder
  cd ${inputPath}/${subject}/GRASE/

  # start the timer
  timer_start="$(date +"Date : %d/%m/%Y Time : %H.%M.%S")"
  printf " \n Beginning ${subject} GRASE Preparation at: \n ${timer_start} \n "

  # Grab echo 1
  fsl5.0-fslroi \
    ${subject}_GRASE.nii.gz \
    ${subject}_GRASE_E1.nii.gz \
    0 1

  # N4 correction
  N4BiasFieldCorrection \
    -d 3 \
    -v 0 \
    -i ${subject}_GRASE_E1.nii.gz \
    -o ${subject}_GRASE_E1_N4.nii.gz
  printf " \n ${subject} N4 Correction Complete \n "

  # Take echo1 to power of 2 to replicate T1 weighting
  fsl5.0-fslmaths \
    ${subject}_GRASE_E1_N4.nii.gz \
    -sqr ${subject}_GRASE_E1_N4_T1rep.nii.gz

  # Brain Extract GRASE 
  antsBrainExtraction.sh \
    -d 3 \
    -k 1 \
    -z 0 \
    -c 3x1x2x3 \
    -a ${subject}_GRASE_E1_N4_T1rep.nii.gz \
    -e ${oasisPath}/T_template0.nii.gz \
    -m ${oasisPath}/T_template0_BrainCerebellumProbabilityMask.nii.gz \
    -f ${oasisPath}/T_template0_BrainCerebellumRegistrationMask.nii.gz \
    -o ${inputPath}/${subject}/GRASE/${subject}_GRASE_E1_N4_T1rep

  # Clean up extra output
  rm *Warp.* *Affine* *Tmp.* *0.*

  printf " \n Creating ${subject} Brain Extraction Quality Control Images "

  # create mask
  ThresholdImage 3 ${subject}_GRASE_E1_N4_T1repBrainExtractionMask.nii.gz segmentationMask.nii.gz 0 0 0 1
  # create RGB from segmentation
  ConvertScalarImageToRGB 3 ${subject}_GRASE_E1_N4_T1repBrainExtractionMask.nii.gz segmentationRgb.nii.gz none custom ${qcPath}/snapColormap.txt 0 6 

  # create tiled mosaic in each orientation
  CreateTiledMosaic -i ${subject}_GRASE_E1_N4_T1rep.nii.gz -r segmentationRgb.nii.gz -o ${qcPath}/GRASE_BE/${subject}.png -a 0.3 -t -1x-1 -d 2 -p mask -s [1,mask,mask] -x segmentationMask.nii.gz -d 2

  # stop the timer
  timer_stop="$(date +"Date : %d/%m/%Y Time : %H.%M.%S")"
  printf " \n \n ${subject} GRASE Preparation Complete \n Started: \n ${timer_start} \n Finished: \n ${timer_stop} \n \n "

done
#####################################################################################
ECOMM

BCOMM
##################################################################################### Prep mcDESPOT
for subject in $subjects
do

  # Change into the subject folder
  cd ${inputPath}/${subject}/IRSPGR/

  # start the timer
  timer_start="$(date +"Date : %d/%m/%Y Time : %H.%M.%S")"
  printf " \n Beginning ${subject} mcDESPOT Preparation at: \n ${timer_start} \n "

  # N4 correction
  N4BiasFieldCorrection \
    -d 3 \
    -v 0 \
    -i ${subject}_IRSPGR.nii.gz \
    -o ${subject}_IRSPGR_N4.nii.gz
  printf " \n ${subject} N4 Correction Complete \n "

  # Brain Extract 
  antsBrainExtraction.sh \
    -d 3 \
    -k 1 \
    -z 0 \
    -c 3x1x2x3 \
    -a ${subject}_IRSPGR_N4.nii.gz \
    -e ${oasisPath}/T_template0.nii.gz \
    -m ${oasisPath}/T_template0_BrainCerebellumProbabilityMask.nii.gz \
    -f ${oasisPath}/T_template0_BrainCerebellumRegistrationMask.nii.gz \
    -o ./${subject}_IRSPGR_N4

  # Clean up extra output
  rm *Warp.* *Affine* *Tmp.* *0.*

  # Create more generous mask with CSF
  fsl5.0-fslmaths \
    ${subject}_IRSPGR_N4BrainExtractionMask.nii.gz \
    -max ${subject}_IRSPGR_N4BrainExtractionCSF.nii.gz \
    -fillh ${subject}_IRSPGR_N4BrainExtractionMaskwCSF.nii.gz

  # apply mask to N4 (to be registered)
  fsl5.0-fslmaths \
    ${subject}_IRSPGR_N4 \
    -mas ${subject}_IRSPGR_N4BrainExtractionMaskwCSF.nii.gz \
    ${subject}_IRSPGR_N4_Brain.nii.gz

  printf " \n Creating ${subject} Brain Extraction Quality Control Images "

  # create mask
  ThresholdImage 3 ${subject}_IRSPGR_N4BrainExtractionMask.nii.gz segmentationMask.nii.gz 0 0 0 1
  # create RGB from segmentation
  ConvertScalarImageToRGB 3 ${subject}_IRSPGR_N4BrainExtractionMask.nii.gz segmentationRgb.nii.gz none custom ${qcPath}/snapColormap.txt 0 6 

  # create tiled mosaic in each orientation
  CreateTiledMosaic -i ${subject}_IRSPGR_N4.nii.gz -r segmentationRgb.nii.gz -o ${qcPath}/mcDESPOT_BE/${subject}.png -a 0.3 -t -1x-1 -d 2 -p mask -s [1,mask,mask] -x segmentationMask.nii.gz -d 2

  # stop the timer
  timer_stop="$(date +"Date : %d/%m/%Y Time : %H.%M.%S")"
  printf " \n \n ${subject} mcDESPOT Preparation Complete \n Started: \n ${timer_start} \n Finished: \n ${timer_stop} \n \n "

done

#####################################################################################
ECOMM

BCOMM
##################################################################################### Register GRASE and mcDESPOT to 3DT1
for subject in ${subjects} # For loop over subject specified above
do

  # start the timer
  timer_start="$(date +"Date : %d/%m/%Y Time : %H.%M.%S")"
  printf " \n Beginning ${subject} GRASE+mcDESPOT <-> 3DT1 Registration: \n ${timer_start} \n "

  # Change dir
  cd ${inputPath}/${subject}/3DT1/

  ############################ GRASE

  # Register
  antsRegistrationSyN.sh \
    -d 3 \
    -f ${subject}_3DT1_N4BrainExtractionBrain.nii.gz \
    -m ${inputPath}/${subject}/GRASE/${subject}_GRASE_E1_N4_Brain.nii.gz \
    -t r \
    -z 1 \
    -j 0 \
    -p d \
    -n ${cores} \
    -x ${subject}_3DT1_N4BrainExtractionMask.nii.gz \
    -o ${subject}_GRASE_E1_N4_Brain

  # apply sharper 3DT1 mask to warped GRASE
  fsl5.0-fslmaths \
    ${subject}_GRASE_E1_N4_BrainWarped.nii.gz \
    -mas ${subject}_3DT1_N4BrainExtractionMask.nii.gz \
    ${subject}_GRASE_E1_N4_BrainWarpedMasked.nii.gz

  printf " \n Creating ${subject} GRASE <-> 3DT1 Registration Quality Control Images "

    # create mask
  ThresholdImage 3 ${subject}_3DT1_N4BrainExtractionMask.nii.gz segmentationMask_wholebrain.nii.gz 0 0 0 1
  # create RGB from segmentation
  # ConvertScalarImageToRGB 3 ${subject}_GRASE_E1_N4_T1repBrainExtractionMask.nii.gz segmentationRgb_wholebrain.nii.gz none custom ${qcPath}/snapColormap.txt 0 6 

  for dim in 0 1 2
  do
    # create 3DT1 tiled mosaic
    CreateTiledMosaic -i ${subject}_3DT1_N4BrainExtractionBrain.nii.gz -r segmentationRgb.nii.gz -a 0.0 -o ${qcPath}/GRASE_3DT1_Reg/${subject}_${dim}_3DT1.png -t -1x-1 -d ${dim} -p mask -s [4,mask+39,mask] -x segmentationMask_wholebrain.nii.gz

    # create GRASE tiled mosaic
    CreateTiledMosaic -i ${subject}_GRASE_E1_N4_BrainWarpedMasked.nii.gz -r segmentationRgb.nii.gz -a 0.0 -o ${qcPath}/GRASE_3DT1_Reg/${subject}_${dim}_GRASE.png -t -1x-1 -d ${dim} -p mask -s [4,mask+39,mask] -x segmentationMask_wholebrain.nii.gz
  done

  ############################ mcDESPOT

  # Register
  antsRegistrationSyN.sh \
    -d 3 \
    -f ${subject}_3DT1_N4BrainExtractionBrain.nii.gz \
    -m ${inputPath}/${subject}/IRSPGR/${subject}_IRSPGR_N4_Brain.nii.gz \
    -t r \
    -z 1 \
    -j 0 \
    -p d \
    -n ${cores} \
    -x ${subject}_3DT1_N4BrainExtractionMask.nii.gz \
    -o ${subject}_IRSPGR_N4_Brain

  # apply sharper 3DT1 mask to warped GRASE
  fsl5.0-fslmaths \
    ${subject}_IRSPGR_N4_BrainWarped.nii.gz \
    -mas ${subject}_3DT1_N4BrainExtractionMask.nii.gz \
    ${subject}_IRSPGR_N4_BrainWarpedMasked.nii.gz

  printf " \n Creating ${subject} mcDESPOT <-> 3DT1 Registration Quality Control Images "

    # create mask
  ThresholdImage 3 ${subject}_3DT1_N4BrainExtractionMask.nii.gz segmentationMask_wholebrain.nii.gz 0 0 0 1
  # create RGB from segmentation
  # ConvertScalarImageToRGB 3 ${subject}_GRASE_E1_N4_T1repBrainExtractionMask.nii.gz segmentationRgb_wholebrain.nii.gz none custom ${qcPath}/snapColormap.txt 0 6 

  for dim in 0 1 2
  do
    # create 3DT1 tiled mosaic
    CreateTiledMosaic -i ${subject}_3DT1_N4BrainExtractionBrain.nii.gz -r segmentationRgb.nii.gz -a 0.0 -o ${qcPath}/mcDESPOT_3DT1_Reg/${subject}_${dim}_3DT1.png -t -1x-1 -d ${dim} -p mask -s [4,mask+39,mask] -x segmentationMask_wholebrain.nii.gz

    # create mcDESPOT tiled mosaic
    CreateTiledMosaic -i ${subject}_IRSPGR_N4_BrainWarpedMasked.nii.gz -r segmentationRgb.nii.gz -a 0.0 -o ${qcPath}/mcDESPOT_3DT1_Reg/${subject}_${dim}_IRSPGR.png -t -1x-1 -d ${dim} -p mask -s [4,mask+39,mask] -x segmentationMask_wholebrain.nii.gz
  done

  # stop the timer
  timer_stop="$(date +"Date : %d/%m/%Y Time : %H.%M.%S")"
  printf " \n \n ${subject} GRASE+mcDESPOT <-> 3DT1 Registration Complete \n Started: \n ${timer_start} \n Finished: \n ${timer_stop} \n \n "

done
#####################################################################################
ECOMM

BCOMM
##################################################################################### Multivariate template creation
for subject in $subjects
do
  # make cp for template creation
  cp ${inputPath}/${subject}/3DT1/${subject}_3DT1_N4BrainExtractionBrain.nii.gz ${templatePath}/${subject}_3DT1.nii.gz
  cp ${inputPath}/${subject}/3DT1/${subject}_GRASE_E1_N4_BrainWarpedMasked.nii.gz ${templatePath}/${subject}_GRASE.nii.gz
  cp ${inputPath}/${subject}/3DT1/${subject}_IRSPGR_N4_BrainWarpedMasked.nii.gz ${templatePath}/${subject}_IRSPGR.nii.gz
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


