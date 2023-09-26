#!/bin/bash

#iterate through /packages/uniform/build/*/* and remove $SRC_DIR and $BUILD_DIR

for d in `find /packages/uniform/build -maxdepth 2 -mindepth 2 -type d -not -path '*/\.*'`
do
    cd $d
    echo "clearing out $d"
    ./9_rm_src.sh
done

