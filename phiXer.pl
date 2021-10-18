#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use Config;

my $dirname = dirname (__FILE__);
my $phixFasta = "$dirname/phix_genome/NC_001422.1.fasta";

my $bwa;
my $samtools;
my $devNull = ">/dev/null 2>&1";

if ($Config{osname} =~/darwin/) {
	$bwa = ( -x "$dirname/bin/darwin/bwa" )
	? "$dirname/bin/darwin/bwa"
	:  die " ERROR: Unable to execute bwa";

	$samtools = ( -x "$dirname/bin/darwin/samtools" )
	? "$dirname/bin/darwin/samtools"
	:  die " ERROR: Unable to execute samtools";
}
else {
	$bwa = ( -x "$dirname/bin/linux/bwa" )
	? "$dirname/bin/linux/bwa"
	:  die " ERROR: Unable to execute bwa";


	$samtools = ( -x "$dirname/bin/linux/samtools" )
	? "$dirname/bin/linux/samtools"
	:  die " ERROR: Unable to execute samtools";
}

my $fastqc  =
  ( -x "$dirname/bin/common/FastQC/fastqc" )
  ? "$dirname/bin/common/FastQC/fastqc"
  : die "ERROR: Unable to execute FastQC\n";

my $inputDir;
my $outputDir;
my $verbose;

Help () if (@ARGV < 2 or !GetOptions(
	'input|i=s' =>\$inputDir,
  'output|o=s'=>\$outputDir,
	'verbose'=>\$verbose,
	)
);

if (!-e $outputDir) {
  mkdir $outputDir;
}

# Get input fastq files
my @fastq = getInputFastq($inputDir);

# Map Fastq to phiX genome and return bams
my @bams  = mapFastqToPhiX(@fastq);

doFastQC(@bams);

####################################################
sub doFastQC {

	my @bams = @_;

	my $cmd = "$fastqc @bams -o $outputDir -f bam";
	print " INFO: $cmd\n" if $verbose;
	system $cmd;
}

####################################################
sub mapFastqToPhiX {

  my @fastq = @_;
	my @bams  = ();
  foreach my $fq1 (grep ($_=~/R1/,  @fastq)) {
    my $fq2 = $fq1;
    $fq2 =~s/R1/R2/;
    if (!-e $fq2) {
      print " ERROR: missing fq2 for $fq1\n";
      exit;
    }
    my @tmpName = split("_", basename($fq1));
    my $sampleName = $tmpName[0];

    my $bam = $outputDir . "/" . "$sampleName.bam";
    my $bai = $bam . ".bai";

    my $cmd = "$bwa mem -t 4 $phixFasta $fq1 $fq2  | $samtools view -bhS -F 4 - ".
    " | $samtools sort -T $sampleName -O BAM -o $bam - $devNull";
		print " INFO: Mapping sample $sampleName\n";
		print " INFO: $cmd\n" if $verbose;
    system $cmd if !-e $bam;

    $cmd = "$samtools index $bam";
		print " INFO: $cmd\n" if $verbose;
    system $cmd if !-e $bai;

    # Now extract mapped reads
    my $flagstat = `$samtools flagstat $bam`;
    chomp $flagstat;

		print " INFO: Mapping summary for sample $sampleName\n";
		my @tmpStr = split("\n", $flagstat);
		my %mapSummary =  (
			'Total_reads'     => $tmpStr[0] =~m/^\d+/g,
			'Multi_mapped'    => $tmpStr[1] =~/^\d+/g,
			'Duplicates'      => $tmpStr[2] =~/^\d+/g,
			'Mapped'          => $tmpStr[4] =~/^\d+/g,
			'Properly_paired' => $tmpStr[8] =~/^\d+/g

    );
		foreach my $metric (keys %mapSummary) {
			print "\t$metric: $mapSummary{$metric}\n";
		}

		push @bams, $bam;

  }
	return @bams;
}

####################################################
sub getInputFastq {

  my $inputDir = shift;

  if (!-e $inputDir) {
    print " ERROR: input dir $inputDir does not exist\n";
    exit;
  }

  my @fastq = glob("$inputDir/*.fastq.gz");
  if (!@fastq) {
    print " ERROR: missing *fastq.gz files on $inputDir\n";
    exit;
  }

  return @fastq
}
####################################################
sub Help {

  print "\n Description: Quality check of PhiX sequences
 Usage: $0
 Version: 1.0

 --input    STRING    Input fastq.gz dir
 --output   STRING    Output dir
 --verbose\n\n";
  exit;
}
