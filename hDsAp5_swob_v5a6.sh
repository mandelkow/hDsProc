#!/bin/bash -e
#
# hDsAp5_swob_v5a6.sh [++++] Process Dante's Sleep1 fMRI dataset.
#
# This script serves two purposes: (See also README.md)
# 1) Copy (link) data files and create a Biowulf swarm to run afni_proc.py on each fMRI experiment.
# 2) Process *one* fMRI experiment (single swarm task) using afni_proc.py among onther things.
#
# USAGE 1: cd dest/dir ; hDsAp5_swob_v5b3.sh -t <task> -S <Job> source/dir
# USAGE 2: cd dest/dir/sub-*/ses-*/run-* ; hDsAp5_swob_v5b3.sh -J <Job>
#
# EXAMPLE:
#   cd /data/AMRI/sleep1/derivatives/hendrik/0101_Ap5_Ric2AlwReg
#   hDsAp5_swob_v5b6.sh -t sleep -S Ric2AlwReg /data/AMRI/sleep1
#   # NOTE: For reference, this command line is written to swarm_jobs.sh
#   # The script prompts for confirmation before 1) copying the data and 2) submitting the swarm to Biowulf.
#   # To (re-)submit the swarm manually: cd ../0101_Ap5_Ric2AlwReg ; ./run_swarm.sh
#
# SEE ALSO: hDsAp4_mksw_v5b2 + hDsAp4_job_v5b2 (functionality split into two files)
# PREC: hDsAp5_swob_v5b5.sh
#
# AUTHOR: Hendrik.Mandelkow@gmail.com, 2020-06

# TODO:
# [x] add card to resp regressors in RicReg.1D
# [/] add censoring from card, resp, SWA,...?
# [x] censor motion more strictly + more widely
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
RWIN="100,100" # phys.regression window + step size see hmat2txt
MinTR=600 # *** min. exp. length 30 minutes. Unset to disable.
XSUB="2 40 53 67" # *** Sleep1 data! # Better use ../hendrik/0000_raw
XRUN="20160902_0250 20170118_0222 20160630_0204 20160630_0609" # Exclude bad runs!

# SLORD="alt+z2"
# if (( $NSL%2 )); then SLORD="alt+z" # if odd # of slices, order 1,3,5,...,2,4,6,...
# else SLORD="alt+z2" # if even # of slices, order 2,4,6,...,1,3,5,...
# fi

#--------------------------------------------------------------------------
# Actually, this is overridden below!
GOF=0 # AP -GOFORIT 0=OFF

#--------------------------------------------------------------------------
HelpText="
USAGE 1: cd dest/dir ; $0 -S <Job> source/dir
USAGE 2: cd output/dir ; $0 -J <Job>
<Job> = 'All' or any combination of RicNwarpReg

-h | --help         # Catch 22
-S | --Swarm All    # make swarm with --Job All (or any of RicNwarpRegGof99)
-J | --Job All      # run single swarm job
-t | --task ''      # default, find any task-*, -t sleep ...for sleep data
-s | --sub          #  subject ID
-W | --rwin         #  '100,100' [or 0 or None] phys.regression window + step size see hmat2txt
-m | --mtr          #  min. TR, exclude experiments with fewer TRs

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
    -W|--rwin) RWIN="$2"; shift 2 ;;
    -m|--mtr) MinTR="$2"; shift 2 ;;
    -*|--*=) echo "Error: Unsupported flag $1" >&2 ; exit 1 ;;
    *) ETC="$ETC $1"; shift ;; # preserve positional arguments
  esac
done
eval set -- "$ETC" # set $@ to positional arguments (without options)
[[ $MODE == Swarm ]] && [[ ! -v TASK ]] && read -p "+ Enter TASK: " TASK # Don't forget to set TASK!
GOF=$( grep -oP "(?<=Gof)([0-9]+)" <<< $JOB || echo 0 )
echo MODE=\"$MODE\"
echo JOB=\"$JOB\"
echo SUB=\"$SUB\"
echo TASK=\"$TASK\"
echo RWIN=\"$RWIN\"
echo MinTR=\"$MinTR\"
echo GOF=$GOF
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
    # JobSh="../../../${0##*/} -t $TASK -J $JOB"
    JobSh="../../../${0##*/} -J $JOB"

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
    find -L $SUB -maxdepth 1 -type d -name "ses-*" -exec mkdir -vp $OutDir/{} \;
    find -L $SUB -maxdepth 1 -type d -name "ses-*" -exec ln -vs $PWD/{} $OutDir/{}/raw \;
    cd $OutDir

    if [[ ! -z $XSUB ]] ; then # ***
        echo
        #< echo +++ WARNING: Exclude subjects 2, 40, 53, 67
        #< set +e ; for F in 02 40 53 67; do rename sub xsub sub-000$F ; done ; set -e
        echo ++++ WARNING: Exclude subjects $XSUB
        set +e ; for F in $XSUB; do rename sub xsub $( printf "sub-%05d" $F) ; done ; set -e
        #< for F in 02 40 53 67; do ( set +e ; rename sub xsub sub-000$F ) ; done # This should work?!?
    fi

    #-------------------------------------------------------------------------------
    # NOTE: fMRI files are expected to be */*/*-$ExId.ext*
    # TODO: Redo this process to depend on 1) a file pattern for find and 
    # 2) a regex-replace to extract $ExId. Then name files Epi.nii. ExId is "stored"
    # in the folder name run-$ExId. Maybe add a symlink by the original name.
    # E.g. FPAT="*/func/*task-sleep*$X.nii*" ... find -path "...sleep*.nii*"
    # ExId=$( echo $FPAT | sed 's/.*task-sleep.*-(.+)\.nii/\1/' )
    cd $InDir
    module load afni
    # for F in $(find sub* -name "*task*.nii*"); do echo mkdir ${F%/*}/${F##*-} ; done
    for F in $(find -L $SUB -path "*/func/*task-$TASK*.nii*") ; do
    # for F in $(find -L $SUB -path $FPATH ) ; do # TODO: This does not work!
        # echo mkdir -p ${F%/*}/${F: -17:-4}
        B=${F##*-} # 2020xxxx_xxxx.nii
        ExId=${B%%.*} # +++ ExId = between last "-" and last "."
        # # echo mkdir -p $OutDir/${F%/*}/run-${B%%.*} # ./the/path/Ex2020xxxx_xxxx
        # mkdir -p $OutDir/${F%/func/*}/run-$ExId # ./the/path/Ex2020xxxx_xxxx
        # cp -avs $InDir/$F $OutDir/${F%/func/*}/run-$ExId/${F##*/}
        # # cp -avs $InDir/$F $OutDir/${F%/func/*}/run-$ExId/$B

        NTR=`3dinfo -nt $InDir/$F`
        ## Skip experiments < 30 minutes!
        if [[ ! -z $MinTR ]] && (( $NTR < $MinTR )) ; then
            echo "+++ Skip short experiment, NTR=$NTR<$MinTR : $F"
            continue
        fi
        ## Skip bad runs
        # if [[ $XRUN == *"$ExId"* ]]; then
        #     echo "++++ Skip bad run: $InDir/$F"
        #     continue
        # fi
        #-------------------------------------------------------------------------------
        # TODO: Check for missing physio. # FIXIT: This does not work... :-(
        # TMP=$InDir/${F%/func/*}/biopac/*_run-$ExId.*
        # if [[ ! -f $TMP ]]; then
        #     #< $InDir/${F/func/biopac}
        #     echo "++++ Skip experiment with missing physio data."
        #     echo -e "\t$TMP"
        #     continue
        # fi
        #-------------------------------------------------------------------------------
        mkdir -p $OutDir/${F%/func/*}/run-$ExId # ./the/path/Ex2020xxxx_xxxx
        cp -as $InDir/$F $OutDir/${F%/func/*}/run-$ExId/${F##*/} && echo + $F
    done
    cd $OutDir

    #-------------------------------------------------------------------------------
    # grep -i error -l sub-*/ses*/run*/*.o # Bad runs (missing physio)!
    if [[ ! -z $XRUN ]] ; then # ***
        echo +++ WARNING: Exclude bad runs $XRUN
        set +e ; for F in $XRUN; do rename run xrun sub-*/ses-*/run-$F ; done ; set -e
        # for F in $XRUN; do rm -rf "sub-*/ses-*/run-$F" ; done
    fi

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
--job-name ${OutDir##*/} --logdir ./log --merge-output \
--sbatch "--mail-type=ALL"
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
    # function hcp_anat {
    #     SRC=`readlink -e $1`
    #     DST=`readlink -e $2`
    #     cd $SRC
    #     # TEST: for F in sub-*/ses-*/run-* ; do echo cp -avrl $SRC/$F/anat_warp $DST/$F ; done
    #     for F in sub-*/ses-*/run-* ; do cp -avrl $SRC/$F/anat_warp $DST/$F ; done
    #     cd -
    # }
    # echo
    # read -p "+ Copy aligned anatomies? from dir: " TMP
    # [[ ! -z $TMP ]] && hcp_anat $TMP .

    #-------------------------------------------------------------------------------
    ### Now submit swarm file?!
    # read -n 1 -p "+ Submit swarm file [y/n]? " YN
    # echo # newline
    # if [[ $YN != y ]] ; then echo ++ Quit. ; exit 0 ; fi
    # ./run_swarm.sh # eval ./run_swarm.sh
    exit 0
fi

#######################################################################################
#######################################################################################
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

# HOWTO test for files / executables on the path:
# if [[ -z $( test -p hmrphys.py ) ]]; then export PATH=$PATH:$HOME/matlab/hMrPhys ; fi
# if [[ -z $( test -p hcalctxt.py ) ]]; then export PATH=$PATH:$HOME/matlab/hDsProc ; fi
export PATH=$HOME/matlab/hMrPhys:$HOME/matlab/hDsProc:$PATH
echo PATH= $PATH

#< HOWTO make alias work inside a bash script:
#< Note that unlike $PATH aliases defined in .bashrc are *not* available inside any script.
#< shopt -s expand_aliases
#< alias hcalctxt=$HOME/matlab/hDsProc/hcalctxt.py
#< alias hmrphys=$HOME/matlab/hMrPhys/hmrphys.py
#< alias hmat2txt=$HOME/matlab/hMrPhys/hmat2txt.py
#< alias hloadHypnoVmrk=$HOME/matlab/hMrPhys/hloadHypnoVmrk.py

#==============================================================================
NTR=$( 3dinfo -nt Epi.nii ) && echo NTR=$NTR
[[ -z $NTR ]] && echo "+++ Error: NTR is empty!" && exit 1
NSL=`3dinfo -nk Epi.nii*` && echo NSL=$NSL
TR=`3dinfo -tr Epi.nii*` && echo TR=$TR
## Skip experiments < 30 minutes!
# if [[ ! -z $MinTR ]] && (( $NTR < $MinTR )) ; then
#     echo "++++ Skip short experiment, NTR ($NTR) < MinTR ($MinTR)."
#     exit
# fi

# SLT=`3dinfo -slice_timing Epi.nii*`
# if [[ $SLT == "1.500000|0.000000|1.559999|0.060000|1.619999|0.120000"* ]]; then
# else echo ERROR: Wrong slice timing info. ; exit 1
# fi 
# "1.500000|0.000000|1.559999|0.060000|1.619999|0.120000|1.679999|0.180000|1.739999|0.240000|1.799999|0.300000|1.859999|0.360000|1.919999|0.420000|1.979999|0.480000|2.039999|0.540000|2.099999|0.600000|2.159999|0.660000|2.219999|0.720000|2.279999|0.780000|2.339999|0.840000|2.399999|0.900000|2.459999|0.960000|2.519999|1.020000|2.579998|1.080000|2.639998|1.140000|2.699998|1.200000|2.759998|1.260000|2.819998|1.320000|2.879998|1.380000|2.939998|1.440000"
#==============================================================================
## Create RIC regressors in 20170304_0123_phy.mat
if [[ $JOB == *"Ric"* ]]; then
    echo "++ [Ric]: Use physio. regressors from hmrphys -> RicRegs.1D"
    if [[ -z $RWIN ]]; then echo "+++ Error: RWIN must be set!" ; exit 1 ; fi

    PHYS=`find ../raw/biopac/ -name "*$ExId.svd"` # or .acq
    #< PHYS=../raw/biopac/*-$ExId.svd # Bad! Never returns empty.
    if [ -z $PHYS ]; then echo ERROR: Missing PHYS! ; exit 1; fi
    echo PHYS= $PHYS

    ln -fs $PHYS $ExId.svd
    hmrphys.py -f "$ExId.svd" # Create ${ExId}_phy.mat
    echo
    ## TODO: Export SPLIT to text ???
    # hmat2txt.py "$ExId\_phy.mat"
    ## Export RespRegHil
    #> hmat2txt.py -f -D -W "160,80" "${ExId}_phy.mat" RespRegHil RicRegs.1D

    NTR=$( 3dinfo -nt Epi.nii )
    # TODO: FIXIT: Why is the # of NTR a problem in only ~6 experiments?!? Note that 1 TR is dropped in AP below!?
    # TODO: FIXIT: What to do when NTR > physio?!? Padded values will be "censored" in RicRegMask
    if true ; then
        hmat2txt.py -f -D "${ExId}_phy.mat" "CardRegHil,RespRegHil" > RicRegs.1D # Don't pad!!!
        TMP=$( grep -vc '#' RicRegs.1D )
        if [ $(($NTR - $TMP)) -gt 20 ]; then
            echo "Error: Length of physio regressors ($TMP) must match data ($NTR)."
            exit 1
        elif [ $NTR -gt $TMP ]; then
            echo "Warning: Length of physio regressors ($TMP) will be padded to match data ($NTR)."
        fi
        hmat2txt.py -f -D -R $NTR "${ExId}_phy.mat" "CardRegHil,RespRegHil" > RicRegs.1D
    fi

    # set -x
    echo
    if [[ $JOB == *"Ricct"* ]]; then
        #< hmat2txt.py -f -D -W $RWIN "${ExId}_phy.mat" CardRegHilTest | head -n $NTR > RicRegs.1D # *** Card only!
        hmat2txt.py -f -D -R $NTR -W $RWIN "${ExId}_phy.mat" CardRegHilTest > RicRegs.1D # *** Card only!
    elif [[ $JOB == *"Ricc"* ]]; then
        echo "++ [Ricc]: Use CARD. regressors from hmrphys -> RicRegs.1D"
        #< hmat2txt.py -f -D -W $RWIN "${ExId}_phy.mat" CardRegHil | head -n $NTR > RicRegs.1D # *** Card only!
        hmat2txt.py -f -D -R $NTR -W $RWIN "${ExId}_phy.mat" CardRegHil > RicRegs.1D # *** Card only!
    elif [[ $JOB == *"Ric2"* ]]; then
        echo "++ [Ric]: Use RESP+CARD regressors from hmrphys -> RicRegs.1D"
        # ( set -x ; hmat2txt.py -f -D -W $RWIN "${ExId}_phy.mat" "CardRegHil,RespRegHil" | head -n $NTR > RicRegs.1D ) # *** Resp+Card! NOT TESTED!
        #< hmat2txt.py -f -D -W $RWIN "${ExId}_phy.mat" "CardRegHil,RespRegHil" | head -n $NTR > RicRegs.1D # *** Resp+Card! NOT TESTED!
        hmat2txt.py -f -D -R $NTR -W $RWIN "${ExId}_phy.mat" "CardRegHil,RespRegHil" > RicRegs.1D
    else # elif [[ $JOB == *"Ricr"* ]]; then
        echo "++ [Ric]: Use RESP. regressors from hmrphys -> RicRegs.1D"
        #< hmat2txt.py -f -D -W $RWIN "${ExId}_phy.mat" RespRegHil | head -n $NTR > RicRegs.1D # *** Resp only!
        hmat2txt.py -f -D -R $NTR -W $RWIN "${ExId}_phy.mat" RespRegHil > RicRegs.1D # *** Resp only!
    fi
    # set +x
    # $(( $NTR != `wc -l RicRegs.1D`)) && echo ERROR && exit 1
    cp -avf RicRegs.1D RicRegsHmp.txt # Save copy of RicRegs from hMrPhys

    hmat2txt.py -f "${ExId}_phy.mat" RespRegMask RespRegMask.txt
#--------------------------------------------------------------------------
### Create censoring file RicRegs_censor.1D from resp/card mask for use with -regress_censor_extern
    echo "++ [???]: Use RespRegMask & CardRegMask for 'external'-censor.1D"
    hmat2txt.py -f -R $NTR "${ExId}_phy.mat" "RespRegMask" RicRegMask.txt
    hmat2txt.py -f -R $NTR "${ExId}_phy.mat" "CardRegMask,RespRegMask" RicRegMask.txt
    hcalctxt.py 'np.c_[X[0].all(1)]' RicRegMask.txt > RicRegs_censor.1D # 0 = censored volume
    #> hcalctxt.py 'si.filtfilt(np.ones(2),[1],X[0])>0]' RicRegs_censor.1D > RicRegs_censor.1D # dilate by 1 or more
fi

#--------------------------------------------------------------------------
if [[ $JOB == *"Rtsc"* ]] ; then
    echo "++ [Rtsc]: Use card. regressors from RetroTS.py for RicRegs.1D"
    set -x
    # 3dinfo -slice_timing Epi.nii* | tr '|' '\n' > SliceTimes.txt # Could be wrong!
    # hmat2txt.py -f "${ExId}_phy.mat" SliceTimes > SliceTimes.txt # *TR !!!
    # hcalctxt.py "np.arange($NSL)[np.argsort(np.r_[($NSL+1)%2:$NSL:2,$NSL%2:$NSL:2])]/$NSL*$TR" > SliceTimes.txt
    NTR=$( 3dinfo -nt Epi.nii )
    NSL=`3dinfo -nk Epi.nii*`
    TR=`3dinfo -tr Epi.nii*`
    Fs=`hmat2txt.py "${ExId}_phy.mat" Fs`

    hmat2txt.py -f "${ExId}_phy.mat" Card > Card.txt
    hmat2txt.py -f "${ExId}_phy.mat" Resp > Resp.txt

    # RetroTS.py -prefix RicRegsRts -v $TR -n $NSL -p $Fs -c Card.txt -r Resp.txt -rvt_out 0 -respiration_out 0 -slice_offset SliceTimes.txt
    RetroTS.py -prefix RicRegsRts -v $TR -n $NSL -p $Fs -c Card.txt -r Resp.txt -rvt_out 0 -respiration_out 0 -slice_order "alt+z2"
    sed '/^#.*/d' RicRegsRts.slibase.1D | head -n $NTR > RicRegs.1D
    hmat2txt2.py -f -S -Z $NSL -W $RWIN -R $NTR RicRegsRts.slibase.1D > RicRegs.1D

    ## For comparisons:
    # hmat2txt.py -f -D -W $RWIN "${ExId}_phy.mat" CardRegHil | head -n $NTR > CardRegHilWin.txt
    # hmat2txt.py -f -D -W $RWIN "${ExId}_phy.mat" RespRegHil | head -n $NTR > RespRegHilWin.txt
    hmat2txt.py -f -D -R $NTR "${ExId}_phy.mat" CardRegHil > CardRegHil.txt
    hmat2txt.py -f -D -R $NTR "${ExId}_phy.mat" RespRegHil > RespRegHil.txt
    cp -a RicRegsRts.slibase.1D CardRegRts.txt
    #< 1dplot "RicRegsRts.slibase.1D[0..3]{0..999}"
    #< 1dplot "CardRegHil.txt[0..3]{0..999}"

    #> hcalctxt.py "X[0][:$NTR]" RicRegsRts.slibase.1D '%.4g' > RicRegs.1D
    #< sed -ni 1,${NTR}p RicRegsRts.slibase.1D
    # 1dcat "RicRegsRts.slibase.1D{0..(($NTR-1))}" > tmp.txt && mv tmp.txt RicRegsRts.slibase.1D
    # ln -svf RicRegsRts.slibase.1D RicRegs.1D
    # Combine RicRegs preserving slice-major order:
    # hcalctxt.py 'np.r_["2",X[0].reshape(X[0].shape[0],50,-1),X[1].reshape(X[1].shape[1],50,-1)]' \
    #     RicRegsHmp.txt RicRegsRts.txt > RicRegs.1D
    
    set +x
fi

#==============================================================================
export FSLOUTPUTTYPE=NIFTI_GZ # stupid FSL ignores extensions!

#==============================================================================
### COPY DATA: mk Epi.nii, Epi_info.txt and Epi1.nii.gz (1st vol.)
if $OW || [ ! -e Epi.nii* ]; then
	3dinfo $ExId.nii* > raw_3dinfo.txt
	#> 3dinfo -slice_timing $ExId.nii* > SliceTimes.txt
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

# HOWTO find substring in bash:
if [[ $JOB == *"Tsh0"* ]]; then
    BLOCKS=$( sed s/tshift// <<< $BLOCKS )
elif [[ $BLOCKS == *"tshift"* ]]; then
    # T0=$( echo "$TR/2.0" | bc -l )
    T0=`python -c "print($TR/2.0)"`
    APAR+=" -tshift_align_to -tzero $T0 " # default: -tzero 0 ; alt: -slice 25
    # APAR+=" -tshift_opts_ts -tzero 0 -tpattern @filename " # default: -tzero mean of -tpattern alt+z2
    # FIXIT: Ugly hack!
    if (( $NSL%2 )); then APAR+=" -tshift_opts_ts -tpattern alt+z " # if odd # of slices, order 1,3,5,...,2,4,6,...
    else APAR+=" -tshift_opts_ts -tpattern alt+z2 " # if even # of slices, order 2,4,6,...,1,3,5,...
    fi
fi

if [[ $JOB == *"Ric"* ]]; then
    TMP=$( grep -vc '#' RicRegs.1D )
    # TMP=$( sed -e '/^#/d' RicRegs.1D | wc -l )
    if [ $NTR -ne $TMP ]; then
        echo "Error: Length of physio regressors ($TMP) must match data ($NTR)."
        exit 1
    fi
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
    OPT3dD+=" -GOFORIT $GOF " # *** ignor collinearity warnings!?
    APAR+=" -regress_censor_first_trs 3 \
    -regress_motion_per_run \
    -regress_censor_motion 0.3 \
    -regress_censor_outliers 0.05 \
    -regress_apply_mot_types demean deriv "
    # APAR+=" -regress_est_blur_epits -regress_est_blur_errts " # Expensive? Only, needed for ClustSim cluster-size threshold
	APAR+=" -regress_opts_3dD -jobs $OMP_NUM_THREADS $OPT3dD "
    if [[ -f RicRegs_censor.1D ]] && (( `grep -c 0 RicRegs_censor.1D` > `grep -c 1 RicRegs_censor.1D` )) ; then
        echo "+++ Warning: More censored (0) than uncensored (1) volumes?!?"
    fi
    [[ -f RicRegs_censor.1D ]] && APAR+=" -regress_censor_extern RicRegs_censor.1D "
else
    BLOCKS=$( sed s/regress// <<< $BLOCKS )
fi

APAR+=" -volreg_zpad 2 " # Might this affect Nwarp?
# APAR+=" -mask_opts_automask -clfrac 0.1 -dilate 4 "
APAR+=" -mask_dilate 4 " # redundant, see above
# APAR+=" -regress_ROI brain " # *** Global signal regression
APAR+=" -execute " # ****
echo
echo + APAR=$APAR #; exit 0
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
    -regress_no_fitts \
    -html_review_style pythonic \
    -keep_rm_files \
    $APAR
fi

#==============================================================================
### AFTERMATH
echo ====================================================================
echo ++ Process results of afni_proc.py...
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
3dTstat -overwrite -mean -prefix Epi_Mc_mean.nii Epi_Mc.nii
3dresample -overwrite -master Epi_Mc_mean.nii -prefix AnaT1_Epi.nii -input AnaT1.nii
3dresample -overwrite -master Epi_Mc_mean.nii -dxyz 1.0 1.0 1.0 -prefix AnaT1_1mm.nii -input AnaT1.nii
3dTstat -overwrite -stdev -prefix Epi_Mc_std.nii Epi_Mc.nii
if [[ $JOB == *"Sca"* ]]; then
    3dcopy -overwrite errts.*.HEAD Epi_Mcr.nii
else
    3dcalc -overwrite -float -prefix Epi_Mcr.nii -a errts.*.HEAD -b Epi_Mc_mean.nii -expr 'a+b'
fi
3dTstat -overwrite -stdev -prefix Epi_Mcr_std.nii errts.*.HEAD
3dcopy rm.epi.volreg.r*.HEAD Epi_Mc_orig.nii.gz # moco only dset, no align
CENSOR=`ls -1 censor_*_combined_?.1D | tail -1`
3dTproject -overwrite -input Epi_Mc_orig.nii -prefix Epi_Mcr_orig.nii \
    -censor $CENSOR -cenmode ZERO -polort 0 -ort X.nocensor.xmat.1D # ...  -mask AUTO
# NOTE: Censored data points are nulled in Epi_Mcr_orig.nii, which is also zero mean.
3dTstat -overwrite -mean -prefix Epi_Mc_mean_orig.nii Epi_Mc_orig.nii
3dcalc -overwrite -float -prefix Epi_Mcr_orig.nii -expr 'a+b' -a Epi_Mcr_orig.nii -b Epi_Mc_mean_orig.nii
[ -f rm.pb??.ricor.betas.r??+orig.HEAD ] && 3dcopy rm.pb??.ricor.betas.r??+orig.HEAD RicBeta.nii.gz
gunzip -f Epi_*.nii.gz AnaT1*.nii.gz # ++++ for Jeff

### remove temporary files
\rm -fr rm.* Segsy _*

### Delete redundant files
cp -sf pb04.$ExId.r*.*.BRIK* all_runs.$ExId*.BRIK*

echo DONE. COMPLETED: $0 
exit 0 # Ensure no exit 1 from above.
