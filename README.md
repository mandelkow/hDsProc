## hDsProc : *Preprocess large-scale sleep fMRI data using [AFNI](https://afni.nimh.nih.gov/) and [SLURM](https://slurm.schedmd.com) on the [Biowulf](https://hpc.nih.gov) cluster.*

AUTHOR: Hendrik.Mandelkow@gmail.com

A fairly compact and efficient processing pipeline implemented in Bash and Python using [afni_proc.py](https://afni.nimh.nih.gov/pub/dist/doc/htmldoc/programs/afni_proc.py_sphx.html#ahelp-afni-proc-py) and the batch processing system SLURM on Biowulf the HPC cluster at the NIH.


## USAGE
> Examples: see `h_15xx_proc.sh`

```
$> hDsAp5_swob_v5a?.sh -h

$> cd output/directory
$> hDsAp5_swob_v5a?.sh -t sleep -S All /input/data/dir
```

`hDsAp5_swob_*` will copy the folder structure and links to the `sub-*_task-sleep_*.nii` files found in `/input/data/dir`. It will also create `run_swarm.sh` and `swarm_jobs.sh` in the output dir.

`run_swarm` submits the jobs in `swarm_jobs.sh` to SLURM. Each compute node executes `hDsAp5_swob_v5a?.sh -J All` on one experiment in one of the output directories. The parameter `All` selects a subset of parameters for `afni_proc.py`. See also `hDsAp5_swob_v5a?.sh -h`.

## Output
* Log files: `.../output/directory/log/slurm-*.out`

* A *great* number of AFNI output files are found in: `../out/dir/sub-00001/ses-1/run-$ExId/$ExId.results/`
  * View quality-control output in `../$ExId.results/QC*/index.html`

  - `Epi_Mc.nii` Preprocessed fMRI time series, aligned to Talairach space by default.
  - `McPar.1D` (= `dfile*.1D`) : time*6 motion parameters
  - `AnaT1_1mm.nii` : T1W anatomy, aligned to Talairach by non-lin. warp
