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
# bhaps2haps.pl
#################################################################################
# Converts a "bhaps" (binary haplotype matrix) file into a text-based space-
# separated haplotype matrix.
#
# Input: bhaps file
# Output: haps file
#################################################################################
use POSIX qw(ceil);
use IO::Uncompress::AnyInflate;
use IO::Compress::Gzip;
use Getopt::Long qw(:config posix_default no_ignore_case);

my $fs=" ";
my $eol="\n";
my $max_buffer_size = 4 * 1024 * 1024; # 4MiB
my $bhaps_magic = "BHAPS1.0.0";
my $bhaps_record_prefix = "REC";

my $in_bhaps_file;
my $out_haps_file;
my $verbose = 0;
my $extra_sep = 0;
sub usage {
    print STDERR "Usage: $0 --input <input_bhaps_file> --output <output_haps_file> [--extra_sep] [--verbose] [--help]\n";
}
GetOptions( "input|i=s" => \$in_bhaps_file,
	    "output|o=s" => \$out_haps_file,
	    "extra_sep|e" => \$extra_sep,
	    "verbose|v" => \$verbose,
	    "help|?" => sub { usage(); exit(0);},
    ) or usage();

if (!$in_bhaps_file) {
    usage();
    die "Must specify --input <input_haps_file>\n";
}

if (!$out_haps_file) {
    usage();
    die "Must specify --output <output_bhaps_file>\n";
}

if ($extra_sep) {
    $eol = $fs.$eol;
}

# open files
my $in_bhaps_fh = fzinopen($in_bhaps_file);
binmode $in_bhaps_fh, ":raw";
my $out_haps_fh = fzoutopen($out_haps_file);

# read and verify magic and header
my $header;
my $bytes_read = sysread($in_bhaps_fh, $header, 15);
die "could not read bhaps header from $in_bhaps_file (read $bytes_read bytes)\n" unless ($bytes_read == 15);

my ($magic, $nhaps) = unpack("a[11]L[1]", $header) or die "could not unpack header\n";

die "invalid magic string [$magic] (expecting [$bhaps_magic])\n" unless ($magic =~ m/^$bhaps_magic/);

verblog("Opened bhaps file with nhaps==$nhaps");

my $recsize = length(pack("a[4]L[1]b[$nhaps]"));
my $buffer_len = int($max_buffer_size/$recsize) * $recsize;

my $buffer;
$bytes_read = sysread($in_bhaps_fh, $buffer, $buffer_len);
my $rec_count = 0;
do {
    foreach my $record (unpack("(a[$recsize])*", $buffer)) {
	my ($recstr, $recno, $hapbits) = unpack("a[4]L[1]b[$nhaps]", $record);
	die "invalid record prefix $recstr (expecting $bhaps_record_prefix)\n" unless ($recstr =~ m/^$bhaps_record_prefix/);
	die "unexpected record number $recno (expecting $rec_count)\n" unless ($recno == $rec_count);
	my @cols = split //, $hapbits;
	die "unexpected number of haps for record number $recno: ".scalar(@cols)." (expecting $nhaps)\n" unless (scalar(@cols) == $nhaps);
	print $out_haps_fh join($fs, @cols).$eol;
	$rec_count++;
    }
    verblog("reading next buffer at rec_count $rec_count");
} while($bytes_read = sysread($in_bhaps_fh, $buffer, $buffer_len));

close $out_haps_fh;
close $in_bhaps_fh;


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

