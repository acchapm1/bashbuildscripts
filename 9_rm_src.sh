#!/bin/bash

source ../../header.source
source ../../module.source
source variables.source

echo-green "[rmsrc] started"

if [ $# -eq 1 ]; then
  BUILD_ID=$1
  echo-green "* using supplied build id... $BUILD_ID"
  SCRATCH_ROOT=/scratch/${SUDO_USER:-$USER}/builds/$PKGNAME/$BUILD_ID
  SRC_DIR=$SCRATCH_ROOT/src
else
  BUILD_ID=$(readlink src | grep -Po '\/([0-9]+)\/' | sed 's#/##g' )
  echo-green "* using existing symlink for build id... $BUILD_ID"
  SCRATCH_ROOT=/scratch/${SUDO_USER:-$USER}/builds/$PKGNAME/$BUILD_ID
  SRC_DIR=$SCRATCH_ROOT/src
fi

if [ ! -z "$BUILD_ID" ]; then
  echo-red "* deleting $SCRATCH_ROOT"
  rm -rf $SCRATCH_ROOT
fi

echo-red "* removing local symlinks"
rm -rf objdir
rm -rf src
rm -rf scratch

echo-red "* deleting _*_output files"
rm -f _*_output

echo-green "[rmsrc] succeeded"

