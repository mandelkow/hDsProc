# h_15xx_proc.sh [++++] Processing data in ../sleep1/15??_* by hDsAp5_swob_v5a6 and code below.
#
# PREC: h_14xx_proc.sh
# AUTHOR: H.Mandelkow, 2021-02-26

BIN="/data/AMRI/bin/hDsProc"
SWOB=$BIN/hDsAp5_swob_v5a6.sh

#==============================================================================
RawDir="/data/AMRI/sleep1"
ProcDir="/data/AMRI/sleep1/derivatives"
AnatDir=$ProcDir/XXX

ProcDir="/data/AMRI/sleep1/derivatives/1501_Ap5a6_AlwReg"
mkdir $ProcDir ; cd $ProcDir
$SWOB -t sleep -S AlwReg $RawDir
# rm -r sub-00002 sub-00067 sub-00040 sub-00053 # Bad subjects!
# rm -r sub*/ses*/run-20160902_0250 sub*/ses*/run-20170118_0222 sub*/ses*/run-20160630_0204 sub*/ses*/run-20160630_0609
# $BIN/hcp_anat.sh $AnatDir .
./run_swarm.sh

grep -i error -l sub*/ses*/run*/*.o
# for F in `grep -i error -l 14*/sub*/ses*/run*/*.o`; do echo rmm -rf ${F%/*} ; done

#------------------------------------------------------------------------------
ProcDir="/data/AMRI/sleep1/derivatives/1502_Ap5a6_Ric2AlwReg"
AnatDir="/data/AMRI/sleep1/derivatives/1501_Ap5a6_AlwReg"
mkdir $ProcDir ; cd $ProcDir
$SWOB -t sleep -S Ric2AlwReg $RawDir
# rm -r sub-00002 sub-00067 sub-00040 sub-00053 # Bad subjects!
# rm -r sub*/ses*/run-20160902_0250 sub*/ses*/run-20170118_0222 sub*/ses*/run-20160630_0204 sub*/ses*/run-20160630_0609
$BIN/hcp_anat.sh $AnatDir .
./run_swarm.sh

grep -i error -l sub*/ses*/run*/*.o

#==============================================================================
cd /data/AMRI/sleep1/derivatives/1502_Ap5a6_Ric2AlwReg
$BIN/hDsRvpa1a1_sba.py
