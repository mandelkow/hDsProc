#!/bin/bash -e

# hDsRvpa_sba.sh [1a1] Regress lagged RVT and PPG-amp. from preprocessed Sleep1 data in Biowulf swarm.
#
# EXAMPLE:
# > cd .../1444_*
# > .../hDsRvpa_sba.sh
# > swarm -f tmp$TMP.swarm -g 32 -t $OMP_NUM_THREADS -m afni --logdir tmp${TMP}_log --merge-output --partition quick,norm
#
# NOTE: 2021-01-04
#   Epi_Mcrv_* : No windowing.
#   Epi_Mcrw1_* : Windowed 100TR but w/o detrend.
#
# SEE: h_RvtLags_sba.sh, hDsAp5_swob_v5b7.sh
# PREC: h_RvtLags_sba.sh
# AUTHOR: Hendrik Mandelkow, 2020-12, v.1a1

if [[ ! $1 == "-J" ]] && [[ -z $SLURM_ARRAY_JOB_ID ]] ; then
    TMP=$RANDOM
    cp -aLf $0 .
    cp -aLf $0 ./tmp${TMP}_job.sh
    export OMP_NUM_THREADS=8 # mult.of 2
    echo "# swarm -f tmp$TMP.swarm -g 32 -t $OMP_NUM_THREADS -m afni --logdir tmp${TMP}_log --merge-output --partition quick,norm" > tmp$TMP.swarm
    # find sub-00* -name Epi_Mc.nii* -printf "cd %h ; $PWD/hDsRvpa_sba.sh\n" >> tmp$TMP.swarm # ***
    # find sub-00* -name Epi_Mc.nii* -printf "cd %h ; ../../../../hDsRvpa1a1_sba.sh\n" >> tmp$TMP.swarm # ***
    find sub-00* -name Epi_Mc.nii* -printf "cd %h ; ../../../../tmp${TMP}_job.sh\n" >> tmp$TMP.swarm # ***
    # swarm -f tmp$TMP.swarm -g 32 -t $OMP_NUM_THREADS -m afni --logdir tmp${TMP}_log --merge-output --partition quick,norm
    # swarm -f tmp$TMP.swarm -g 32 -t $OMP_NUM_THREADS -m afni --logdir tmp${TMP}_log --merge-output --maxrunning 100 --time 12:00:00 --partition norm
    # swarm -f tmp$TMP.swarm -g 32 -t $OMP_NUM_THREADS -m afni --logdir tmp${TMP}_log --merge-output --partition norm,quick
    echo "# swarm -f tmp$TMP.swarm -g 32 -t $OMP_NUM_THREADS -m afni --logdir tmp${TMP}_log --merge-output --partition norm,quick" >>  tmp$TMP.swarm
    set -x
    head tmp$TMP.swarm # print .swarm

    exit 0
fi

###############################################################################
###############################################################################
RWIN="100,100" # ***
Out='Epi_Mcrw' # *** Epi_Mcrv Epi_Mcrw
PHYS="../rvt_phy.mat"
[[ ! -f $PHYS ]] && PHYS="../2*_phy.mat" # ***
NTR=`3dinfo -nt Epi_Mc.nii*`

hmat2txt -f -R $NTR $PHYS RespRegRvt > RespRvtWin.txt
#< hcalctxt "np.concatenate([hshift0(X[0][:,:1],n) for n in (1,4)],1)" RespRvtWin.txt # No clue, why this does not work!?!
hcalctxt "hshifts0(X[0],4,0)" RespRvtWin.txt > tmp.txt ; mv tmp.txt RespRvtWin.txt
hmat2txt -f -W $RWIN txt RespRvtWin.txt RespRvtWin.txt
ORT+=" -ort RespRvtWin.txt"

hmat2txt -f -R $NTR $PHYS CardRegAmp > CardAmpWin.txt
hcalctxt "hshifts0(X[0],1,3)" CardAmpWin.txt > tmp.txt ; mv tmp.txt CardAmpWin.txt
hmat2txt -f -W $RWIN txt CardAmpWin.txt CardAmpWin.txt
ORT+=" -ort CardAmpWin.txt"

hcalctxt "X[0][:,:1]*0+1" CardAmpWin.txt > ConstWin.txt
hmat2txt -f -W $RWIN txt ConstWin.txt ConstWin.txt
ORT+=" -ort ConstWin.txt" # ***

ln -sf censor_*_combined_3.1D ${Out}_censor.1D
# hcalctxt 'si.filtfilt([1]*3,[1],X[0]==0)==0' censor_*_combined_3.1D > ${Out}_censor.1D
# hcalctxt "X[0][:$NTR] * X[1]" ${Sig}0.txt ${TMP}_censor.1D > tmp.txt ; mv tmp.txt ${Sig}0.txt

# TODO: Replace with 3dDeconv or 3dREML?
# 3dTproject -polort 0 -input Epi_Mc.nii* -mask Epi_mask.nii* \
#    -ort "X.nocensor.xmat.1D" -ort "RespRvtWin.txt" -ort "CardAmpWin.txt" -ort "ConstWin.txt" \
3dTproject -polort 0 -input Epi_Mcr.nii* -mask Epi_mask.nii* \
    -censor ${Out}_censor.1D -cenmode ZERO \
    -ort "X.nocensor.xmat.1D" $ORT \
    -overwrite -prefix "$Out.nii"

#< 3dcalc -overwrite -prefix ${TMP}.nii -expr 'a*b' -a ${TMP}.nii -b ${TMP}_censor.1D    
#< 3dTstat -overwrite -mask Epi_mask.nii -nzstdev -prefix ${Out}_std.nii ${Out}.nii
3dTstat -overwrite -mask Epi_mask.nii -stdev -prefix ${Out}_std.nii ${Out}.nii
# 3dcalc -overwrite -prefix ${Out}_Vdr.nii -expr '(a^2-b^2)/b^2' -a ${Out}_std.nii -b Epi_Mcr_std.nii
3dcalc -overwrite -prefix ${Out}_Vdr.nii -expr '(a^2-b^2)/b^2*c' -a ${Out}_std.nii -b Epi_Mcr_std.nii -c Epi_mask.nii

3dcalc -overwrite -float -prefix $Out.nii -a $Out.nii -b Epi_Mc_mean.nii* -expr 'a+b'

exit 0

# find sub* -name Epi_Mcrv.nii -execdir 3dTstat -overwrite -mask Epi_mask.nii -stdev -prefix Epi_Mcrv_std.nii Epi_Mcrv.nii \;
# find sub* -name Epi_Mcrv.nii -execdir 3dcalc -overwrite -prefix Epi_Mcrv_Vdr.nii -expr '(a^2-b^2)/b^2*c' -a Epi_Mcrv_std.nii -b Epi_Mcr_std.nii -c Epi_mask.nii
# find sub-00056/ -name Epi_Mcrv_Vdr.nii -exec fsleyes {} -dr -0.2 0.2 -cm brain_colours_diverging_bwr \;
# find sub* -name Epi_Mcrv_Vdr.nii -exec 3dMean -prefix Epi_Mcrv_Vdr_mean.nii {} +
# for F in sub* ; do find $F -name Epi_Mcrv_Vdr.nii -exec 3dMean -prefix $F/Epi_Mcrv_Vdr_mean.nii {} + ; done
