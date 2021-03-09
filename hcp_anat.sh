#!/bin/bash
# hcp_anat.sh [-c|-l] source_dir [dest_dir]

if [[ $1 == -* ]]; then MODE=$1 ; shift ; fi
SRC=`readlink -e $1`
if [[ -z $2 ]]; then DST=$PWD ; else DST=`readlink -e $2` ; fi
cd $SRC
if [[ $MODE == "-c" ]]; then
    for F in sub-*/ses-*/run-* ; do cp -avr $SRC/$F/anat_warp $DST/$F ; done
elif [[ $MODE == "-l" ]]; then
    for F in sub-*/ses-*/run-* ; do cp -avrl $SRC/$F/anat_warp $DST/$F ; done
else
    for F in sub-*/ses-*/run-*/anat_warp ; do ln -vs $SRC/$F $DST/$F ; done
fi
cd -
