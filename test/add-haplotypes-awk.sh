#!/bin/bash
# adds pairs of columns in order specified
haps=$1
indices=$(cat ${2}|perl -p -e 's/\ /_/g')

awk 'BEGIN { FS = " "; ORS=""; n=split("'${indices}'",newArray,"_")}
{for (i = 1; i <= n; i+=2) print $(newArray[i]+1)+$(newArray[(i+1)]+1) FS; 
print "\n"} ' ${haps}

