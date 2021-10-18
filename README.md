# PhiXer
PhiX qc control consists on the sequencing of the PhiX bacteriophage to ensure that the sequencing is reliable and well calibrated.
This control is tipycally present within the Undetermined fastq's (reads that could not be de-multiplexed properly), since it is not indexed during the sample prep.

The following script (phiXer.pl) performs a basic QC control in two steps:
* Alignment of the Undetermined fq's to the PhiX genome (bwa)
* Gathering of QC metrics (FastQC)

## Requirements
* Perl, tested on v5.26.1
No further installation is needed since binaries are bundled together with the release.

## Usage:
 ```
 perl phiXer.pl --input <input_fastq_dir> --output <output_dir>
 ```
Once the analysis is done, check the HTML summaries created by FastQC.
