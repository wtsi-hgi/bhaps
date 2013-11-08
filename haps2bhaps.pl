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
# haps2bhaps.pl
#################################################################################
# Converts a text-based space-separated haplotype matrix into "bhaps" (binary 
# haplotype matrix) format.
#
# Input: haps file
# Output: bhaps file (optionally gzip compressed if filename ends in .gz)
#################################################################################
use POSIX qw(ceil);
use IO::Uncompress::AnyInflate;
use IO::Compress::Gzip;
use Getopt::Long qw(:config posix_default no_ignore_case);

my $fs=" ";

my $in_haps_file;
my $out_bhaps_file;
my $nhaps;
my $max_buffer_size = 4 * 1024 * 1024; # 4MiB

my $verbose=0;
sub usage {
    print STDERR "Usage: $0 --nhaps <number_of_haps> --input <input_haps_file> --output <output_bhaps_file> [--verbose] [--help]\n";
}
GetOptions( "input|i=s" => \$in_haps_file,
	    "output|o=s" => \$out_bhaps_file,
	    "nhaps|n=i"=> \$nhaps,
	    "verbose|v" => \$verbose,
	    "help|?" => sub { usage(); exit(0);},
    ) or usage();

if (!$nhaps) {
    usage();
    die "Must specify --nhaps <number_of_haps>\n";
}

if (!$in_haps_file) {
    usage();
    die "Must specify --input <input_haps_file>\n";
}

if (!$out_bhaps_file) {
    usage();
    die "Must specify --output <output_bhaps_file>\n";
}

# open files
my $in_haps_fh = fzinopen($in_haps_file);
my $out_bhaps_fh = fzoutopen($out_bhaps_file);
binmode $out_bhaps_fh, ":raw";

# write magic and header
my $headerlen = syswrite($out_bhaps_fh, pack("a[11]L[1]", "BHAPS1.0.0", $nhaps));
verblog("Wrote $headerlen byte header");

my $buffer;
my $buffer_len = 0;
my $recno = 0;
while(my $line = <$in_haps_fh>) {
    chomp $line;
    my @cols = split(/$fs/, $line);
    if(@cols != $nhaps) {
	die "read unexpected number of columns (expecting: $nhaps, found: ".scalar(@cols)."\n";
    }
    my $record = pack("a[4]L[1]b[$nhaps]", "REC", $recno, join('',@cols));
    my $recsize = length($record);
    if($buffer_len + $recsize > $max_buffer_size) {
	# this record will put the buffer over the limit, write the buffer now
	my $write_count = syswrite($out_bhaps_fh, $buffer);
	if($write_count != $buffer_len) {
	    die "tried to write $buffer_len bytes but only wrote $write_count bytes\n";
	}
	$buffer = "";
	$buffer_len = 0;
    }
    $buffer .= $record;
    $buffer_len += $recsize;
    $recno++;
}

# write final buffer
my $write_count = syswrite($out_bhaps_fh, $buffer);
if($write_count != $buffer_len) {
    die "tried to write $buffer_len bytes but only wrote $write_count bytes\n";
}


close $in_haps_fh;
close $out_bhaps_fh;


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

