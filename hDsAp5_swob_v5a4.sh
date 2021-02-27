#!/bin/bash -e
# hDsAp5_swob_v5a4.sh [++++] Process Dante's Sleep1 fMRI dataset.
# 1) Copy (link) data folders and create a Biowulf swarm to run afni_proc.py on each fMRI experiment.
# 2) Process *one* fMRI experiment (single swarm task) using afni_proc.py (among onther things).
# Run via h_DsAea1_mksw* or "find -exec ..."
#
# USAGE 1: cd dest/dir ; hDsAp5_swob_v5b3.sh -t <task> -S <Job> source/dir
# USAGE 2: cd dest/dir/sub-*/ses-*/run-* ; hDsAp5_swob_v5b3.sh -J <Job>
#
# SEE ALSO: hDsAp4_mksw_v5b2 + hDsAp4_job_v5b2 (same in two files)
# PREC: h_DsAp1_mksw_v4b8.sh

# AUTHOR: Hendrik.Mandelkow@gmail.com, 2020-06

# TODO:
# [ ] add card to resp regressors in RicReg.1D
# [ ] add censoring from card, resp, SWA,...?
# [ ] censor motion more strictly + more widely
# [ ] scale to % sig change!
# [ ] deal with colinearity and -GOFORIT

#==========================================================================
# if [[ -z $1 || ${1:0:1} == '-' ]]; then
# echo $HelpText
# echo ERROR: Missing sub-command input \$1! ; exit 1 ;
# fi
# MODE=$1

#==========================================================================
# TASK='' # any task-* ... for Db data
# TASK='sleep' # For Ds data
MODE='Swarm'
JOB='All'
InDir='/data/AMRI/sleep1'
SUB='sub*'
#--------------------------------------------------------------------------
GOF='99' # AP -GOFORIT 0=OFF

#--------------------------------------------------------------------------
HelpText="
USAGE 1: cd dest/dir ; $0 -S <Job> source/dir
USAGE 2: cd output/dir ; $0 -J <Job>
<Job> = 'All' or any combination of RicNwarpReg

-h | --help         # Catch 22
-S | --Swarm All    # make swarm with --Job All (or any of RicNwarpRegGof99)
-J | --Job All      # run single swarm job
-t | --task ''      # default, find any task-*, -t sleep ...for sleep data

"
#--------------------------------------------------------------------------
# HOWTO do simple input parsing in bash:
CMDLINE=$( echo "$0 $@" )
ETC=""
if [[ $# == 0 ]]; then echo "$HelpText" ; exit 0 ; fi
while (( "$#" )); do
  case "$1" in
    -h|--help) echo "$HelpText" ; exit 0 ;; # quotes necessary!
    -S|--Swarm) MODE=Swarm ; JOB=$2 ; shift 2 ;;
    -J|--Job) MODE=Job ; JOB=$2 ; shift 2 ;;
    -t|--task) TASK=$2; shift 2 ;;
    -s|--sub) SUB="$2"; shift 2 ;;
    -*|--*=) echo "Error: Unsupported flag $1" >&2 ; exit 1 ;;
    *) ETC="$ETC $1"; shift ;; # preserve positional arguments
  esac
done
eval set -- "$ETC" # set $@ to positional arguments (without options)
[[ $MODE == Swarm ]] && [[ ! -v TASK ]] && read -p "+ Enter TASK: " TASK # Don't forget to set TASK!
echo MODE=\"$MODE\"
echo JOB=\"$JOB\"
echo SUB=\"$SUB\"
echo TASK=\"$TASK\"
if [[ -z $JOB || ${JOB:0:1} == '-' ]]; then echo Error: Bad JOB parameter! ; exit 1 ; fi
echo $@ ; 
# exit 0 # TEST
#==========================================================================

#< if [[ ${MODE:0:5} == "Swarm" ]]; then
if [[ $MODE == "Swarm" ]]; then
    echo "##### PREPARE SWARM #####"
    OutDir=$PWD
    InDir=${1%/} # remove trailing /
    # InDir=/data/AMRI/sleep1
    # if [[ ! -z $1 ]] ; then InDir=$1 ; fi
    #< JobSh=~/matlab/hDsBw/hDsAp4_job_v4b3.sh
    # JobSh="$0 -J $JOB"
    # JobSh="$PWD/${0##*/} -J $JOB"
    JobSh="../../../${0##*/} -t $TASK -J $JOB"

    #-------------------------------------------------------------------------------
    read -n 1 -p "+ Use OutDir= $OutDir [y/n]? " YN
    if [[ $YN != y ]] ; then echo -e "\n++ Abort!" ; exit 0 ; fi
    echo # newline
    echo "+ Using InDir=$InDir"
    echo "+ Using JobSh=$JobSh"

    #-------------------------------------------------------------------------------
    cp -aLf $0 $OutDir # cp this script to OutDir for the record

    #-------------------------------------------------------------------------------
    ### COPY DATA TO OutDir AS HARD LINKS
    cd $InDir
    echo $PWD
    find $SUB -maxdepth 1 -type d -name "ses-*" -exec mkdir -p $OutDir/{} \;
    find $SUB -maxdepth 1 -type d -name "ses-*" -exec ln -s $PWD/{} $OutDir/{}/raw \;
    cd $OutDir

    #-------------------------------------------------------------------------------
    # NOTE: fMRI files are expected to be */*/*-$ExId.ext*
    # TODO: Redo this process to depend on 1) a file pattern for find and 
    # 2) a regex-replace to extract $ExId. Then name files Epi.nii. ExId is "stored"
    # in the folder name run-$ExId. Maybe add a symlink by the original name.
    # E.g. FPAT="*/func/*task-sleep*$X.nii*" ... find -path "...sleep*.nii*"
    # ExId=$( echo $FPAT | sed 's/.*task-sleep.*-(.+)\.nii/\1/' )
    cd $InDir
    # for F in $(find sub* -name "*task*.nii*"); do echo mkdir ${F%/*}/${F##*-} ; done
    for F in $(find $SUB -path "*/func/*task-$TASK*.nii*") ; do
        # echo mkdir -p ${F%/*}/${F: -17:-4}
        B=${F##*-} # 2020xxxx_xxxx.nii
        ExId=${B%%.*}
        # echo mkdir -p $OutDir/${F%/*}/run-${B%%.*} # ./the/path/Ex2020xxxx_xxxx
        mkdir -p $OutDir/${F%/func/*}/run-$ExId # ./the/path/Ex2020xxxx_xxxx
        cp -avs $InDir/$F $OutDir/${F%/func/*}/run-$ExId/${F##*/}
        # cp -avs $InDir/$F $OutDir/${F%/func/*}/run-$ExId/$B
    done
    cd $OutDir

    #-------------------------------------------------------------------------------
    # Write swarm command to new swarm file:
    # NOTE: The longest run (>3000 volumes) requires about 10.5GB for regression. See:
    # grep -B 1 Killed log/*.o
    # DO NOT INDENT THE FOLLOWING LITERAL BLOCK!
    cat > run_swarm.sh << EOL
# Make this swarm file: $CMDLINE
# Run this swarm file: run_swarm.sh
# Exported parameters should be available to sbatch jobs:
# export InDir=$InDir
# export ApOpt="$ApOpt"
export FSL_MEM=32
export OMP_NUM_THREADS=32 # ***
# export MEM=32
# export CPU=32 # ***
swarm -f swarm_jobs.sh \
-g \$FSL_MEM -t \$OMP_NUM_THREADS --time=36:00:00 --gres=lscratch:64 \
--partition=norm --err-exit -v 2 \
--job-name ${OutDir##*/} --logdir $OutDir/log --merge-output \
--sbatch "--mail-type=ALL -D $OutDir"
# --sbatch "--export=OMP_NUM_THREADS=$CPU,FSL_MEM=$MEM --mail-type=ALL -D $OutDir"
EOL
# NO SPACE BEFORE OR AFTER EOL!!!

    chmod u+x run_swarm.sh

    #-------------------------------------------------------------------------------
    # Write swarm_jobs.sh : First copy run_swarm.sh but comment # each line
    # Then use find to write one line per ExDir found.
    sed -e 's/^/# /' run_swarm.sh > swarm_jobs.sh # prepend # to each line
    echo "# SWARM JOBS: ---------------------------------------" >> swarm_jobs.sh
    # find sub-*/ses-*/run-*/ -name "*task-sleep*.nii" -printf "cd %h && $JobSh $MODE %f\n" >> swarm_jobs.sh # +++
    find sub-*/ses-*/run-*/ -name "*task-*.nii" -printf "cd %h && $JobSh \n" >> swarm_jobs.sh # +++
    # HOWTO set TMPDIR to scratch disk in Biowulf swarm job:
    #> find sub-*/ses-*/run-*/ -name "*task-*.nii" -printf "export TMPDIR=/lscratch/\$SLURM_JOB_ID ; cd %h && $JobSh \n" >> swarm_jobs.sh # +++

    #-------------------------------------------------------------------------------
    ### Now submit swarm file?!
    read -n 1 -p "+ Submit swarm file [y/n]? " YN
    echo # newline
    if [[ $YN != y ]] ; then echo ++ Quit. ; exit 0 ; fi
    ./run_swarm.sh # eval ./run_swarm.sh

    exit 0
fi

#######################################################################################
if [[ $JOB == "All" ]]; then JOB="RicNwarpReg" ; fi # ***
echo "+++ JOB= $JOB"
[[ -d /lscratch/$SLURM_JOB_ID ]] && export TMPDIR=/lscratch/$SLURM_JOB_ID

### Find file e.g. 2018xxxx_0357.nii and strip extension.
echo PWD= $PWD
# ln ${SLURM_SUBMIT_DIR}/log/*_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.e
# ln ${SLURM_SUBMIT_DIR}/log/*_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.o
# [[ -f ../../../log/*_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.o ]] && ln -s ../../../log/*_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.o
# Hard links won't create if file not found!
set +e
ln ../../../log/*_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.o
ln ../../../log/*_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.e
set -e

ls sub-*.nii*
EPI=$( ls sub-*.nii* )
if [[ ! -z $1 ]]; then EPI=$1; fi
echo "+++ EPI= $EPI"
cp -vP $EPI Epi.nii
ExId=$EPI
#< ExId=`echo $ExId | sed -r 's/.*-([0-9_]+)\.nii.*/\1/g'`
#< ExId=`echo $ExId | sed -r 's/.*-//g'`
#< echo sub-00006_ses-2_task-sleep_run-20160901_2340.nii | sed -r 's/.*-([0-9_]+)\.nii/Ex\1/g'
#< ${tmp: -17:-4}
ExId=${ExId##*-}
ExId=${ExId%%.*}
# ExId=${ExId: -13}
if [ -z $ExId ]; then echo ERROR: Missing ExId! ; exit 1; fi
echo ExId = $ExId
# cp -vP $1 $ExId.nii

module load afni fsl FFmpeg
# export FSL_MEM=16
export AFNI_COMPRESSOR="GZIP" # default compression?!
OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
if [[ -z $OMP_NUM_THREADS ]]; then OMP_NUM_THREADS=2 ; fi
if (("$OMP_NUM_THREADS" < "2")); then echo "Better set OMP_NUM_THREADS > 1!"; exit 1 ; fi

OW=false # overwrite flag
TR0=0 # Remove volumes 0..TR0-1
ORI=LPI # = LR,PA,IS desired orientation # NOTE: 3dresample -orient asks for *ORIGIN*!
ANAT=`find ../../ses-*/raw/anat/ -name "*anat-mprage.nii*" -print -quit`
if [ -z $ANAT ]; then echo ERROR: Missing ANAT! ; exit 1; fi
3dinfo $ANAT

#==============================================================================
## Create RIC regressors in 20170304_0123_phy.mat
if [[ $JOB == *"Ric"* ]]; then
    PHYS=`find ../raw/biopac/ -name "*$ExId.svd"` # or .acq
    #< PHYS=../raw/biopac/*-$ExId.svd # Bad! Never returns empty.
    if [ -z $PHYS ]; then echo ERROR: Missing PHYS! ; exit 1; fi
    echo PHYS= $PHYS

    ln -fs $PHYS $ExId.svd
    ~/matlab/hMrPhys/hmrphys.py -f "$ExId.svd" # Create ${ExId}_phy.mat
    ## TODO: Export SPLIT to text ???
    # ~/matlab/hMrPhys/hmat2txt.py "$ExId\_phy.mat"
    ## Export RespRegHil
    #> ~/matlab/hMrPhys/hmat2txt.py -f -D -W "160,80" "${ExId}_phy.mat" RespRegHil RicRegs.1D
    NTR=$( 3dinfo -nt Epi.nii )
    # TODO: FIXIT: Why is the # of NTR a problem in only ~6 experiments?!? Note that 1 TR is dropped in AP below!?
    ~/matlab/hMrPhys/hmat2txt.py -f -D -W "160,80" "${ExId}_phy.mat" RespRegHil | head -n $NTR > RicRegs.1D # *** Resp only!
    # ~/matlab/hMrPhys/hmat2txt.py -f -D -W "160,80" "${ExId}_phy.mat" "CardRegHil,RespRegHil" | head -n $NTR > RicRegs.1D # *** Resp+Card! NOT TESTED!

    # TODO:
    # ~/matlab/hMrPhys/hmat2txt.py -f "${ExId}_phy.mat" RespRegMask RespRegMask.txt
    # 1d_tool -input RespRegMask.txt -collapse_cols min -extreme_mask -1 0.1 \
    # -write_censor RespRegMask_censor.1D -write_CENSORTR RespRegMask_CENSORTR.txt \
    # -censor_first_trs 3 -censor_prev_TR -censor_next_TR # also use these?!?
fi

#==============================================================================
export FSLOUTPUTTYPE=NIFTI_GZ # stupid FSL ignores extensions!

#==============================================================================
### COPY DATA: mk Epi.nii, Epi_info.txt and Epi1.nii.gz (1st vol.)
if $OW || [ ! -e Epi.nii* ]; then
	3dinfo $ExId.nii* > raw_3dinfo.txt
	3dinfo -slice_timing $ExId.nii* > SliceTiming.txt
	#> cp -vP $1 Epi.nii.gz
	fslmaths $ExId.nii* Epi.nii.gz -odt float
	# fslroi $ExId Epi 0 32 # *** DEBUG TEST
fi
if [ ! -e Epi.nii* ]; then echo ERROR: Epi.nii is missing.; exit 1 ; fi

#------------------------------------------------------------------------------
# FIX ORIENTATION - obsolete?
# NB: slice direction I->S. RAS preserves slice numbers.
if false && [ `3dinfo -orient Epi.nii*` == ARI ] ; then
	echo + Fix faulty raw data orientation.
	3dLRflip -AP -overwrite -prefix tmp.nii.gz Epi.nii.gz # +++
	mv tmp.nii.gz Epi.nii.gz
	echo + Change orientation to $ORI
	3dresample -orient $ORI -prefix Epi.nii.gz -inset Epi.nii* -overwrite
fi
if false && [ `3dinfo -orient Epi.nii*` != $ORI ] ; then
	echo ERROR: orientation should be $ORI
	exit 1
	# 3dresample -orient $ORI -prefix Epi.nii.gz -inset Epi.nii.gz -overwrite
fi

#==============================================================================
## Chose an anatomical template:
# + MNI152_2009_template_SSW.nii.gz
# + TT_N27_SSW.nii.gz
# + HaskinsPeds_NL_template1.0_SSW.nii.gz
TLRC="TT_N27_SSW.nii.gz"
TLRC=`@FindAfniDsetPath $TLRC`/$TLRC

## Redo for each exp. in ./anat_warp/, unless it were copied before.
# set +x # trace off
if [[ $JOB == *"Alc"* ]] ; then # ***
    ln -s $ANAT AnaT1.nii
    # @Align_Centers -overwrite -grid -base $TLRC -dset $ANAT -prefix "AnaT1_center.nii"
    @Align_Centers -grid -base $TLRC -dset AnaT1.nii -child Epi.nii
    rm Epi.nii*
    rename Epi_shft Epi Epi_shft.nii*
    ANAT="AnaT1_shft.nii*"
fi
if [[ ! -d "./anat_warp" ]] && [[ ! $JOB == *"Als"* ]]; then
    @SSwarper -input $ANAT -subid $ExId -base $TLRC -odir ./anat_warp
fi
#==============================================================================
# AFNI_PROC.PY
# SEE ALSO: h_DsAp1_mksw_v4a2.sh
if [[ $JOB == "None" ]]; then echo ++++ Skip afni_proc! ; exit 0 ; fi
if [[ $JOB == *"Sca"* ]]; then
    BLOCKS=" -blocks despike ricor tshift align tlrc volreg mask scale regress"
else
    BLOCKS=" -blocks despike ricor tshift align tlrc volreg mask regress"
fi
APAR="" # redundant!
# HOWTO find substring in bash:
if [[ $JOB == *"Ric"* ]]; then
    APAR+=" -ricor_regs RicRegs.1D -ricor_regress_method per-run "
    # APAR+=" -ricor_regs_rm_nlast 1 " # *** drop last sample in regressors
    # Now redundant bc of $NTR above?!
else
    BLOCKS=$( sed s/ricor// <<< $BLOCKS )
fi
if [[ $JOB == *"Nwarp"* ]] || [[ $JOB == *"Alw"* ]]; then # NON-linear align to Talairach
    APAR+=" -copy_anat ./anat_warp/anatSS.$ExId.nii* -anat_has_skull no "
    APAR+=" -volreg_tlrc_warp -tlrc_base $TLRC "
    APAR+=" -tlrc_NL_warp -tlrc_NL_warped_dsets \
        anat_warp/anatQQ.$ExId.nii* \
        anat_warp/anatQQ.$ExId.aff12.1D \
        anat_warp/anatQQ.$ExId\_WARP.nii* "
elif [[ $JOB == *"Als"* ]]; then # *** Align to subj anatomy NOT Talairach!
    BLOCKS=$( echo $BLOCKS | sed 's/ tlrc / /' )
    APAR+=" -copy_anat $ANAT -anat_has_skull yes "
else # Linear (affine) align to Talairach
    APAR+=" -copy_anat ./anat_warp/anatSS.$ExId.nii* -anat_has_skull no "
    APAR+=" -volreg_tlrc_warp -tlrc_base $TLRC "
fi
# if [[ ! $JOB == *"Nwarp"* ]]; then APAR=$( sed s/-tlrc_NL_[^-]*//g <<< $APAR ); fi
if [[ $JOB == *"Reg"* ]]; then 
    GOF=$( echo $JOB | sed -nr 's/Gof([0-9]+)/\1/p' ); if [[ -z $GOF ]]; then GOF=0 ; fi
    OPT3dD+=" -GOFORIT $GOF " # *** ignor collinearity warnings!?
    APAR+=" -regress_censor_first_trs 3 \
    -regress_motion_per_run \
    -regress_censor_motion 0.3 \
    -regress_censor_outliers 0.05 \
    -regress_apply_mot_types demean deriv \
    -regress_est_blur_epits \
    -regress_est_blur_errts \
	-regress_opts_3dD -jobs $OMP_NUM_THREADS $OPT3dD "
	#< -regress_opts_3dD -jobs $OMP_NUM_THREADS -GOFORIT 9 $OPT3dD "
    [[ -f RespRegMask_censor.1D ]] && APAR+=" -regress_censor_extern RespRegMask_censor.1D "
else
    BLOCKS=$( sed s/regress// <<< $BLOCKS )
fi

APAR+=" -volreg_zpad 2 " # Might this affect Nwarp?
# APAR+=" -mask_opts_automask -clfrac 0.1 -dilate 4 "
APAR+=" -mask_dilate 4 " # redundant, see above
# APAR+=" -regress_ROI brain " # *** Global signal regression
echo APAR=$APAR #; exit 0
# NOTE:
if true && [[ ! -d "$ExId.results" ]]; then
    rm -f proc.$ExId output.proc.$ExId
    # -blocks despike ricor tshift align tlrc volreg mask scale regress
    afni_proc.py \
    $BLOCKS \
	-subj_id $ExId \
	-dsets Epi.nii* \
	-align_unifize_epi yes \
    -align_opts_aea -cost lpc+ZZ -ginormous_move -deoblique on -check_flip \
    -volreg_align_to MIN_OUTLIER \
    -volreg_align_e2a \
    -volreg_warp_dxyz 2.0 \
    -volreg_no_extent_mask \
    -mask_apply epi \
    -mask_segment_anat yes \
    -mask_segment_erode yes \
    $APAR \
    -html_review_style pythonic \
    -keep_rm_files \
    -execute
fi

#==============================================================================
### AFTERMATH
# ~/matlab/hDsProc/hDsAp_job2_v4b3.sh $ExId.results
echo ====================================================================
set -x # echo commands
cd $ExId.results
# set -e
# ls errts.*.HEAD
set +e # tolerate errors
ln -sf dfile.r01.1D McPar.1D
3dcopy -overwrite anat_final.*.HEAD AnaT1.nii
3dcopy -overwrite mask_group+tlrc.HEAD Epi_mask.nii
3dcopy -overwrite pb??.*.r??.volreg+*.HEAD Epi_Mc.nii
cp -sf Epi_Mc.nii $( echo pb??.*.r??.volreg+*.HEAD | sed s/HEAD$/nii/ )
# rm pb??.*.r??.volreg+*.BRIK*
3dTstat -overwrite -mean -prefix Epi_Mc_mean.nii Epi_Mc.nii*
3dresample -overwrite -master Epi_Mc_mean.nii -prefix AnaT1_Epi.nii -input AnaT1.nii
3dresample -overwrite -master Epi_Mc_mean.nii -dxyz 1.0 1.0 1.0 -prefix AnaT1_1mm.nii -input AnaT1.nii
3dTstat -overwrite -stdev -prefix Epi_Mc_std.nii Epi_Mc.nii*
if [[ $JOB == *"Sca"* ]]; then
    3dcopy -overwrite errts.*.HEAD Epi_Mcr.nii
else
    3dcalc -overwrite -float -prefix Epi_Mcr.nii -a errts.*.HEAD -b Epi_Mc_mean.nii* -expr 'a+b'
fi
3dTstat -overwrite -stdev -prefix Epi_Mcr_std.nii errts.*.HEAD
3dcopy rm.epi.volreg.r*.HEAD Epi_Mc_orig.nii.gz
3dcopy rm.pb??.ricor.betas.r??+orig.HEAD RicBeta.nii.gz
gunzip -f Epi_*.nii.gz AnaT1*.nii.gz

# remove temporary files
\rm -fr rm.* Segsy

### Delete redundant files
cp -sf pb04.$ExId.r*.*.BRIK* all_runs.$ExId*.BRIK*
# cp -lf pb04.$ExId.r*.*.BRIK* all_runs.$ExId*.BRIK*
# echo "3dTcat -prefix pb00.$ExId.r??.tcat Epi.nii'[0..$]'" > hmk_pb00.sh
# rm pb00.*.BRIK*
# rm pb0[013].*.BRIK*
# pb00.$ExId.r??.tcat+orig.BRIK : remove dummy vols
# pb01.$ExId.r??.despike+orig.BRIK : despike
# pb02.$ExId.r??.ricor+orig.BRIK : RIC, poly.baseline added back
# pb03.$ExId.r??.tshift+orig.BRIK : tshift
# pb04.$ExId.r??.volreg+tlrc.BRIK : moco [= all_runs.$ExId+tlrc.BRIK ]
# fitts.*.BRIK
# errts.*.BRIK

echo DONE. $0 completed normally. # Ensure no exit 1 from above.
