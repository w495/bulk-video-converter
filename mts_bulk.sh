#!/usr/bin/env bash

for file in ls ./input/* ; do
    bash mts_convert.sh -i $file -c config.yaml -O ./out/
done
