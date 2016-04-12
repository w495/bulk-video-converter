#!/usr/bin/env bash

for file in ./input/* ; do
    bash mts_convert.sh -i $file -c config.yaml -O ./out/ 
done
