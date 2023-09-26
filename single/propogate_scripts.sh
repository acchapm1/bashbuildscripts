#!/bin/bash

#iterate through /packages/uniform/build/*/* and checks if all scripts
#have all applicable symlinks
#symlink overwrites (with normal files) will no be impacted

for d in `find /packages/uniform/build -maxdepth 2 -mindepth 2 -type d -not -path '*/\.*'`
do
    cd $d
    find ../../buildscripts -type f -name "[0-9]_*" | xargs cp -s -n -t .
done

