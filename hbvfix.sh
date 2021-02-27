#!/bin/bash
# Fix internal file references for BrainVision EEG files (*.vhdr & *.vmrk) that were renamed.
# Replaces the lines DataFile=... and MarkerFile=... with current file name.
#
# USAGE: hbvfix.sh *.vhdr *.vmrk
# 
# AUTHOR: Hendrik Mandelkow, 2020-08-31

for Fname in $@ ; do
    [[ $Fname == *.eeg ]] || [[ $Fname == *.dat ]] && continue
    echo $Fname
    Fbase=${Fname%.*}
    Fbase=${Fname##*/}
    # sed -rn "s/^([^;]+File=).+(\.[^\.]+)$/\1$Fbase\2/p" $Fname # TEST
    cp -a $Fname $Fname~
    sed -ri "s/^([^;]+File=).+(\.[^\.]+)$/\1$Fbase\2/g" $Fname
    #< sed -ri "s/^(DataFile=).+(\.[^\.]+)$/\1$Fbase\2/g" $Fname
    touch -r $Fname~ $Fname
done
