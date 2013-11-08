bhaps
=====

bhaps consists of a set of tools to assist with simulations involving haplotype and genotype data. 
It includes utilites for converting between binary (bhaps) and text (haps) file formats, as well 
as for sampling from those haplotypes (in either format) to create genotype files. 

We wrote bhaps as a quick hack to reduce the CPU and I/O requirements of a large-scale simulation in 
which we need to sample from a population of simulated haplotypes in order to generate chromosome-wide 
simulated genotypes (in this case to feed into the [GEMMA](http://stephenslab.uchicago.edu/software.html#gemma) 
software).  The genotype output files from `sample_bhaps.pl` or `sample_haps.pl` are therefore in a 
GEMMA-compatible format (supporting both gzip-compressed and uncompressed formats). 

With our data, a ~40GiB uncompressed haps file becomes a 335MiB compressed bhaps file, a 99.2% reduction 
in file size (and also I/O requirements). You could also choose to use the 2.5GiB uncompressed bhaps file 
which still amounts to a 93.75% reduction in storage and I/O requirements, but won't need to use as much 
CPU for (de)compression. Depending on whether I/O, storage, or CPU are more precious commodities in your 
environment, you might want to choose one over the other. 

If you are uncomfortable with the binary bhaps format but are suffering from limited I/O and storage, 
you could instead use compressed haps files, which in our hands results in a 766MiB file but with 
considerably longer running time for the sampling (3-5x) than with the binary format. 


Toy Example
-----------

Consider an input haps file containing the following matrix: 
```
0 0 0 0 1 1 1 1
1 1 1 1 0 0 0 0
0 0 1 1 0 0 1 1
1 1 0 0 1 1 0 0
0 1 0 1 0 1 0 1
1 0 1 0 1 0 1 0
```

This file contains 8 haplotypes (corresponding to the columns) at 6 sites (corresponding to the rows). 
We might be interested in generating a genotype file which consists of random pairs of these haplotypes 
put together. We can do that using `sample_haps.pl` as follows:

```
$ cat in.haps
0 0 0 0 1 1 1 1
1 1 1 1 0 0 0 0
0 0 1 1 0 0 1 1
1 1 0 0 1 1 0 0
0 1 0 1 0 1 0 1
1 0 1 0 1 0 1 0
$ sample_haps.pl --n 3 --input in.haps --output out.geno --output_indices out.indices --verbose
Found 8 haplotypes in input matrix.
Set random seed to 937645825
Generating 3*2 indices between 0 and 7
Writing indices to out.indices
Processing input matrix to output matrix, sampling line-by-line
finished.
$ cat out.indices 
2 7 6 2 0 3
$ cat out.geno 
1 1 0
1 1 2
2 2 1
0 0 1
1 0 1
1 2 1
```

Because we did not specify a random seed (using `--seed <seed>`), `sample_haps.pl` has generated one 
for us (and reported it to STDERR because we did specify `--verbose`). 

We can generate exactly the same data again by supplying that value using `--seed <seed>`:
```
$ sample_haps.pl --n 3 --input in.haps --output out2.geno --output_indices out2.indices --seed 937645825 --verbose
Found 8 haplotypes in input matrix.
Set random seed to specified seed 937645825
Generating 3*2 indices between 0 and 7
Writing indices to out2.indices
Processing input matrix to output matrix, sampling line-by-line
finished.
$ cat out2.indices 
2 7 6 2 0 3
$ cat out2.geno
1 1 0
1 1 2
2 2 1
0 0 1
1 0 1
1 2 1
```

We can also convert the haps file to a compressed bhaps file (the recommended input format for `sample_bhaps.pl`), 
and use that to sample from:
```
$ haps2bhaps.pl --nhaps 8 --input in.haps --output out.bhaps.gz --verbose
Wrote 15 byte header
$ sample_bhaps.pl --n 3 --input out.bhaps.gz --output out3.geno.gz --output_indices out3.indices --seed 937645825 --verbose
Opened bhaps file with nhaps==8
Set random seed to specified seed 937645825
Generating 3*2 indices between 0 and 7
Writing indices to out3.indices
Processing input matrix to output matrix, sampling row-by-row
reading next buffer at rec_count 6
finished.
$ cat out3.indices 
2 7 6 2 0 3
$ zcat out3.geno.gz 
1 1 0
1 1 2
2 2 1
0 0 1
1 0 1
1 2 1
```

