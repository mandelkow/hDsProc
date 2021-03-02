for F in sub-00* ; do find  -name anat_final*.HEAD -printf %p  -quit ; done | xargs 3dMean -verbose -prefix AnatTlrc_mean.nii
