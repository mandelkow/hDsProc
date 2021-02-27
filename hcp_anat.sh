#!/bin/bash

SRC=`readlink -e $1`
DST=`readlink -e $2`
cd $SRC
# TEST: for F in sub-*/ses-*/run-* ; do echo cp -avrl $SRC/$F/anat_warp $DST/$F ; done
for F in sub-*/ses-*/run-* ; do cp -avrl $SRC/$F/anat_warp $DST/$F ; done
cd -
