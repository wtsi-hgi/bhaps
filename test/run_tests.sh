#!/bin/bash

testdir=$(dirname "$(readlink -f "$0")")
echo -n "entering: "
pushd ${testdir} || (echo "could not find testdir: ${testdir}" && exit 1)

failure=0

function fail(){
    echo "fail"
    failure=1
}

function ok(){
    echo "ok"
}

test=1
echo -n "[${test}] testing haps->bhaps->haps conversion... "
rm -f test.${test}.*
../haps2bhaps.pl --input test.haps --output test.${test}.bhaps --nhaps 8
../bhaps2haps.pl --input test.${test}.bhaps --output test.${test}.haps
diff test.haps test.${test}.haps && ok && rm test.${test}.* || fail

test=2
echo -n "[${test}] testing haps->bhaps->haps conversion (extra_sep)... "
rm -f test.${test}.*
../haps2bhaps.pl --input test_extra_space.haps --output test.${test}.bhaps --nhaps 8
../bhaps2haps.pl --input test.${test}.bhaps --output test.${test}.haps --extra_sep
diff test_extra_space.haps test.${test}.haps && ok && rm test.${test}.* || fail

test=3
echo -n "[${test}] testing sample_haps against awk standard... "
rm -f test.${test}.*
../sample_haps.pl --n 2 --input test_extra_space.haps --output test.${test}.geno --output_indices test.${test}.indices --extra_sep
./add-haplotypes-awk.sh test_extra_space.haps test.${test}.indices > test.${test}.awk.geno
diff test.${test}.awk.geno test.${test}.geno && ok && rm test.${test}.* || fail

test=4
echo -n "[${test}] testing sample_bhaps against awk standard... "
rm -f test.${test}.*
../haps2bhaps.pl --input test_extra_space.haps --output test.${test}.bhaps --nhaps 8
../sample_bhaps.pl --n 2 --input test.${test}.bhaps --output test.${test}.geno --output_indices test.${test}.indices --extra_sep
./add-haplotypes-awk.sh test_extra_space.haps test.${test}.indices > test.${test}.awk.geno
diff test.${test}.awk.geno test.${test}.geno && ok && rm test.${test}.* || fail

test=5
echo -n "[${test}] testing that sample_bhaps and sample_haps produce the same indices for given seed... "
rm -f test.${test}.*
../haps2bhaps.pl --input test.haps --output test.${test}.bhaps --nhaps 8
../sample_haps.pl --n 2 --input test.haps --output test.${test}.haps.geno --output_indices test.${test}.haps.indices --extra_sep --seed 314159
../sample_bhaps.pl --n 2 --input test.${test}.bhaps --output test.${test}.bhaps.geno --output_indices test.${test}.bhaps.indices --extra_sep --seed 314159
diff test.${test}.haps.indices test.${test}.bhaps.indices && ok && rm test.${test}.* || fail

test=6
echo -n "[${test}] testing that sample_bhaps and sample_haps produce the same geno file for given seed... "
rm -f test.${test}.*
../haps2bhaps.pl --input test.haps --output test.${test}.bhaps --nhaps 8
../sample_haps.pl --n 2 --input test.haps --output test.${test}.haps.geno --output_indices test.${test}.haps.indices --extra_sep --seed 314159
../sample_bhaps.pl --n 2 --input test.${test}.bhaps --output test.${test}.bhaps.geno --output_indices test.${test}.bhaps.indices --extra_sep --seed 314159
diff test.${test}.haps.geno test.${test}.bhaps.geno && ok && rm test.${test}.* || fail

test=7
echo -n "[${test}] testing haps->bhaps(gz)->haps(gz)->bhaps->haps(gz)->bhaps(gz)->haps conversion... "
rm -f test.${test}.*
../haps2bhaps.pl --input test.haps --output test.${test}.bhaps1.gz --nhaps 8
../bhaps2haps.pl --input test.${test}.bhaps1.gz --output test.${test}.haps2.gz
../haps2bhaps.pl --input test.${test}.haps2.gz --output test.${test}.bhaps3 --nhaps 8
../bhaps2haps.pl --input test.${test}.bhaps3 --output test.${test}.haps4.gz
../haps2bhaps.pl --input test.${test}.haps4.gz --output test.${test}.bhaps5.gz --nhaps 8
../bhaps2haps.pl --input test.${test}.bhaps5.gz --output test.${test}.haps6
diff test.haps test.${test}.haps6 && ok && rm test.${test}.* || fail

test=8
echo -n "[${test}] testing sample_haps against awk standard using gzip compression... "
rm -f test.${test}.*
gzip -c test_extra_space.haps > test.${test}.haps.gz
../sample_haps.pl --n 2 --input test.${test}.haps.gz --output test.${test}.geno --output_indices test.${test}.indices --extra_sep
./add-haplotypes-awk.sh test_extra_space.haps test.${test}.indices > test.${test}.awk.geno
diff test.${test}.awk.geno test.${test}.geno && ok && rm test.${test}.* || fail

test=9
echo -n "[${test}] testing sample_bhaps against awk standard using gzip compression... "
rm -f test.${test}.*
../haps2bhaps.pl --input test_extra_space.haps --output test.${test}.bhaps.gz --nhaps 8
../sample_bhaps.pl --n 2 --input test.${test}.bhaps.gz --output test.${test}.geno --output_indices test.${test}.indices --extra_sep
./add-haplotypes-awk.sh test_extra_space.haps test.${test}.indices > test.${test}.awk.geno
diff test.${test}.awk.geno test.${test}.geno && ok && rm test.${test}.* || fail

test=10
echo -n "[${test}] testing that sample_bhaps and sample_haps produce the same indices for given seed with replacement... "
rm -f test.${test}.*
../haps2bhaps.pl --input test.haps --output test.${test}.bhaps --nhaps 8
../sample_haps.pl --n 2 --input test.haps --output test.${test}.haps.geno --output_indices test.${test}.haps.indices --extra_sep --seed 314159 --with_replacement
../sample_bhaps.pl --n 2 --input test.${test}.bhaps --output test.${test}.bhaps.geno --output_indices test.${test}.bhaps.indices --extra_sep --seed 314159 --with_replacement
diff test.${test}.haps.indices test.${test}.bhaps.indices && ok && rm test.${test}.* || fail

test=11
echo -n "[${test}] testing that sample_bhaps and sample_haps produce the same geno file for given seed with replacement... "
rm -f test.${test}.*
../haps2bhaps.pl --input test.haps --output test.${test}.bhaps --nhaps 8
../sample_haps.pl --n 2 --input test.haps --output test.${test}.haps.geno --output_indices test.${test}.haps.indices --extra_sep --seed 314159 --with_replacement
../sample_bhaps.pl --n 2 --input test.${test}.bhaps --output test.${test}.bhaps.geno --output_indices test.${test}.bhaps.indices --extra_sep --seed 314159 --with_replacement
diff test.${test}.haps.geno test.${test}.bhaps.geno && ok && rm test.${test}.* || fail

test=12
echo -n "[${test}] testing that sample_bhaps indices without replacement do not contain repeat indices... "
rm -f test.${test}.*
../sample_haps.pl --n 2 --input test.haps --output test.${test}.haps.geno --output_indices test.${test}.haps.indices --extra_sep --seed 314159
if [ -z $(cat test.${test}.haps.indices | perl -pi -e 's/\ /\n/g' | sort | uniq -d) ]
then 
    ok && rm test.${test}.*
else
    fail
fi

echo -n "all tests complete, returning to: "
popd

exit ${failure}
