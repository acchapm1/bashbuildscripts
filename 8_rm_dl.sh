#!/bin/bash

source ../../header.source
source ../../module.source
source variables.source

echo-green "[rmdl] started"
echo-red "* deleting ${DOWNLOAD_DIR}/"
rm -rf $DOWNLOAD_DIR
simple_error_check

if [ $? -eq 0 ]; then
  echo-green "[rmdl] succeeded"
else
  echo-red "[rmdl] failed"
  exit 1
fi

