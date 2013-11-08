#!/usr/bin/perl -w
#################################################################################
#
# Copyright (c) 2013 Genome Research Ltd.
# 
# Author: Joshua C. Randall <jcrandall@alum.mit.edu>
# 
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.
# 
#################################################################################

use strict;
use warnings;

#################################################################################
# sample_bhaps.pl
#################################################################################
# Samples haplotypes from a matrix with haplotypes (0,1) as columns and rows as 
# genomic positions. Outputs a matrix with genotypes (allele count; 0,1,2) as 
# columns and rows as genomic positions (row order is preserved from the input).
# 
# Input is in binary (bhaps) format.
# Output is a haps matrix with space-separated columns.
#################################################################################
use Getopt::Long qw(:config posix_default no_ignore_case);
use IO::Uncompress::AnyInflate;
use IO::Compress::Gzip;

my $fs=" ";
my $ofs=" ";
my $max_buffer_size = 4 * 1024 * 1024; # 4MiB
my $bhaps_magic = "BHAPS1.0.0";
my $bhaps_record_prefix = "REC";
my $eol="\n";

my $in_bhaps_file;
my $out_matrix_file;
my $seed;
my $out_indices_file;
my $n;
my $extra_sep = 0;
my $verbose=0;
sub usage {
    die "Usage: $0 --n <number_of_genotypes_to_produce> --input <input_bhaps_file> --output <output_matrix_file> --output_indices <output_haplotype_indices_file> [--seed <random_seed>] [--extra_sep] [--verbose] [--help]\n";
}

GetOptions( "input|i=s" => \$in_bhaps_file,
	    "output|o=s" => \$out_matrix_file,
	    "seed|s=i" => \$seed,
	    "output_indices=s" => \$out_indices_file,
	    "n=i" => \$n,
	    "extra_sep|e" => \$extra_sep,
	    "verbose|v" => \$verbose,
	    "help|?" => sub { usage(); },
    ) or usage();

if (!$n) {
    die "Must specify --n <number_of_genotypes_to_produce>\n";
} elsif ($n <= 0) {
    die "Must specify positive value for --n <number_of_genotypes_to_produce>\n";
}

if (!$in_bhaps_file) {
    die "Must specify --input <input_bhaps_file>\n";
}

if (!$out_matrix_file) {
    die "Must specify --output <output_matrix_file>\n";
}

if (!$out_indices_file) {
    die "Must specify --output_indices <output_haplotype_indices_file>\n";
}

if ($extra_sep) {
    $eol = $fs.$eol;
}

# open files 
my $in_bhaps_fh = fzinopen($in_bhaps_file);
binmode $in_bhaps_fh, ":raw";
my $out_matrix_fh = fzoutopen($out_matrix_file);
my $out_indices_fh = fzoutopen($out_indices_file);

# read header and get number of haplotypes
my $header;
my $bytes_read = sysread($in_bhaps_fh, $header, 15);
die "could not read bhaps header from $in_bhaps_file (read $bytes_read bytes)\n" unless ($bytes_read == 15);
my ($magic, $nhaps) = unpack("a[11]L[1]", $header) or die "could not unpack header\n";
die "invalid magic string [$magic] (expecting [$bhaps_magic])\n" unless ($magic =~ m/^$bhaps_magic/);
verblog("Opened bhaps file with nhaps==$nhaps");


# set random seed
if($seed) {
    srand($seed) or die "could not set random seed to $seed\n";
    verblog("Set random seed to specified seed $seed");
} else {
    $seed = srand();
    verblog("Set random seed to $seed");
}

# generate n*2 random numbers between 0 and $nhaps-1
my @indices;
my @h1_indices;
my @h2_indices;
verblog("Generating $n*2 indices between 0 and ".($nhaps-1));
for (my $i=0; $i<$n*2; $i++) {
    my $index = int(rand($nhaps));
    push @indices, $index;
    if($i%2==0) {
	push @h1_indices, $index;
    } else {
	push @h2_indices, $index;
    }
}

if (scalar(@h1_indices) != scalar(@h2_indices)) {
    die "h1_indices and h2_indices lengths differed\n";
}

# output indices to file
verblog("Writing indices to $out_indices_file");
print $out_indices_fh join($ofs, @indices)."\n";



# prepare to read buffer
my $recsize = length(pack("a[4]L[1]b[$nhaps]"));
my $buffer_len = int($max_buffer_size/$recsize) * $recsize;
my $buffer;

# read into buffer and process row-by-row
$bytes_read = sysread($in_bhaps_fh, $buffer, $buffer_len);
my $rec_count = 0;
verblog("Processing input matrix to output matrix, sampling row-by-row");
do {
    foreach my $record (unpack("(a[$recsize])*", $buffer)) {
	my ($recstr, $recno, $hapbits) = unpack("a[4]L[1]a[$nhaps]", $record) or die "could not unpack record $rec_count\n";
	die "invalid record prefix $recstr (expecting $bhaps_record_prefix)\n" unless ($recstr =~ m/^$bhaps_record_prefix/);
	die "unexpected record number $recno (expecting $rec_count)\n" unless ($recno == $rec_count);
	
	# extract haplotype columns, add into genotypes, and output
	my $gtline;
	my @cols = split //, $hapbits;
	for (my $i=0; $i<$n; $i++) {
	    $gtline .= (vec($hapbits,$h1_indices[$i],1)+vec($hapbits,$h2_indices[$i],1)).$ofs;
	}
	$gtline =~ s/[$ofs]$/$eol/ or die "could not find final field separator in gtline [$gtline]\n";
	print $out_matrix_fh $gtline;
	$rec_count++;
    }
    verblog("reading next buffer at rec_count $rec_count");
} while($bytes_read = sysread($in_bhaps_fh, $buffer, $buffer_len));

verblog("finished.");


close $in_bhaps_fh;
close $out_matrix_fh;
close $out_indices_fh;


sub verblog {
    my $message = shift;
    if($verbose) {
	print STDERR $message."\n";
    }
}



sub fzinopen {
    my $filename = shift || "";
    my $fh;
    if($filename && ($filename =~ m/\.(gz|zip|bz2)$/)) {
	$fh = new IO::Uncompress::AnyInflate $filename or die "Could not open $filename using AnyInflate for input\n";
    } else {
	$fh = new IO::File;
	$fh->open("<$filename") or die "Could not open $filename for input\n";
    }
    return $fh;
}

sub fzoutopen {
    my $filename = shift || "";
    my $fh;
    if($filename && ($filename =~ m/\.gz$/)) {
	$fh = new IO::Compress::Gzip $filename or die "Could not open $filename using gzip for output\n";
    } else {
	$fh = new IO::File;
	$fh->open(">$filename") or die "Could not open $filename for output\n";
    }
    return $fh;
}
