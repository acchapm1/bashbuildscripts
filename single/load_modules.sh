#!/bin/bash

if [ -e variables.source ]
then
  source variables.source

  COMBINED="module purge && "
  
  for dep in "${BUILD_DEPS[@]}"
  do
    COMBINED+="module load $dep && "
  done
  
  echo "source variables.source"
  echo "${COMBINED::-3}"
else
  echo "Usage instructions:"
  echo "Use this script in a directory containing a \`variables.source\` file."
fi

