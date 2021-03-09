#!/bin/bash
# hcp_anat.sh [+++] Copy (-c), link (-l) or sym-link $source/sub-*/ses-*/run-*/anat_warp to $PWD/... or $dest/...
#
# USAGE: hcp_anat.sh [-c|-l] source_dir [dest_dir]
#
# SEE ALSO: hDsAp5_swob_*.sh
# AUTHOR: H.Mandelkow, 2020

# HOWTO use sed to print 1st block of comments (help): [[ $# -eq 0 ]]
if [[ -z $1 ]] || [[ $1=='-h' ]]; then echo; sed -n '/^# /,/^$/p ; /^$/q' $0; exit 0; fi
if [[ -z $1 ]]; then echo ERROR: Missing input SOURCE_DIR ; exit 1; fi

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
