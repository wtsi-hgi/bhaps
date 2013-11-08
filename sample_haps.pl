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
# sample_haps.pl
#################################################################################
# Samples haplotypes from a matrix with haplotypes (0,1) as columns and rows as 
# genomic positions. Outputs a matrix with genotypes (allele count; 0,1,2) as 
# columns and rows as genomic positions (row order is preserved from the input).
#
# Input: genotype count to sample, optional random seed, haps file 
# Output: genotype matrix, file of sampled indices (both can be gzip compressed)
#################################################################################
use Getopt::Long qw(:config posix_default no_ignore_case);
use IO::Uncompress::AnyInflate;
use IO::Compress::Gzip;
use List::Util qw(shuffle);

my $fs=" ";
my $ofs=" ";
my $eol="\n";

my $in_haps_file;
my $out_haps_file;
my $seed;
my $out_indices_file;
my $n;
my $with_replacement=0; #if set, choose haplotypes with replacement rather than without 
my $extra_sep = 0;
my $verbose=0;
sub usage {
    die "Usage: $0 --n <number_of_genotypes_to_produce> --input <input_haps_file> --output <output_haps_file> --output_indices <output_haplotype_indices_file> [--with_replacement] [--seed <random_seed>] [--extra_sep] [--verbose] [--help]\n";
}

GetOptions( "input|i=s" => \$in_haps_file,
	    "output|o=s" => \$out_haps_file,
	    "seed|s=i" => \$seed,
	    "output_indices=s" => \$out_indices_file,
	    "n=i" => \$n,
	    "extra_sep|e" => \$extra_sep,
	    "with_replacement|r" => \$with_replacement,
	    "verbose|v" => \$verbose,
	    "help|?" => sub { usage(); },
    ) or usage();

if (!$n) {
    die "Must specify --n <number_of_genotypes_to_produce>\n";
} elsif ($n <= 0) {
    die "Must specify positive value for --n <number_of_genotypes_to_produce>\n";
}

if (!$in_haps_file) {
    die "Must specify --input <input_haps_file>\n";
}

if (!$out_haps_file) {
    die "Must specify --output <output_haps_file>\n";
}

if (!$out_indices_file) {
    die "Must specify --output_indices <output_haplotype_indices_file>\n";
}

if ($extra_sep) {
    $eol = $fs.$eol;
}

# open files (using gzip if ending in gz)
my $in_haps_fh = fzinopen($in_haps_file);
my $out_haps_fh = fzoutopen($out_haps_file);
my $out_indices_fh = fzoutopen($out_indices_file);

# check how many columns in input matrix
my $line = <$in_haps_fh>;
chomp $line;
my $nhaps = scalar(split(/$fs/, $line));
if ($nhaps % 2 != 0) {
    die "must have an even number of haplotype columns in input matrix\n";
}
verblog("Found $nhaps haplotypes in input matrix.");

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
if ($with_replacement) {
    # with replacement
    verblog("Generating $n*2 indices with replacement between 0 and ".($nhaps-1));
    for (my $i=0; $i<$n*2; $i++) {
	my $index = int(rand($nhaps));
	push @indices, $index;
    }
} else {
    # without replacement
    verblog("Generating $n*2 indices without replacement between 0 and ".($nhaps-1));
    @indices = (shuffle(0 .. ($nhaps-1)))[0 .. (($n*2)-1)];
}

# copy the indices into haplotype 1 and haplotype 2 arrays
my @h1_indices;
my @h2_indices;
for (my $i=0; $i<$n*2; $i++) {
    if($i%2==0) {
	push @h1_indices, $indices[$i];
    } else {
	push @h2_indices, $indices[$i];
    }
}
if (scalar(@h1_indices) != scalar(@h2_indices)) {
    die "h1_indices and h2_indices lengths differed\n";
}

# output indices to file
verblog("Writing indices to $out_indices_file");
print $out_indices_fh join($ofs, @indices)."\n";

# process input matrix to output matrix line-by-line, adding haplotypes into genotypes as we go
verblog("Processing input matrix to output matrix, sampling line-by-line");
my $count = 0;
do { # we already have first $line from before, might as well use it
    chomp $line;
    my @haps = split(/$fs/, $line, -1);
    my @gts;
    for (my $i=0; $i<$n; $i++) {
	my $h1_index = $h1_indices[$i];
	my $h2_index = $h2_indices[$i];
	push @gts, ($haps[$h1_index] + $haps[$h2_index]);
    }
    print $out_haps_fh join($ofs, @gts).$eol;
    $count++;
    if($count % 10000 == 0) {
	verblog("$count");
    }
} while($line = <$in_haps_fh>);

verblog("finished.");

close $in_haps_fh;
close $out_haps_fh;
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

