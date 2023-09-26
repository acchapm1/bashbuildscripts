#!/bin/bash

source ../../header.source
source ../../module.source
source variables.source

#----------------------------------------------------------------------------#
# ./0_download.sh                                                            #
# This script downloads source code in archived form, precompiled binaries   #
# or clones a git repo.  It places it in the download/ directory             #
# with a standardized name (removing versions, etc.) for ease of automation. #
# $WGET_URL - the URL to download or the full repo                           #
# $WGET_DEST - standarized filename from versioned filename.                 #
# $EXTRACTED_DIRNAME - the path created from cloning the git repo.           #
#----------------------------------------------------------------------------#

echo-green "[download] started"

if [ ! -d "$DOWNLOAD_DIR" ]; then
  echo-green "* creating directory $DOWNLOAD_DIR"
  mkdir -p $DOWNLOAD_DIR
fi

cd $DOWNLOAD_DIR
simple_error_check

# if file download is corrupt or otherwise improper, or clone is incomplete,
# rely on ./9_rm_src.sh to clear out and then redownload.
case "$WGET_DEST" in
*.git )
  if [ -d "$DOWNLOAD_DIR/$EXTRACTED_DIRNAME" ]; then
    echo-green "* using existing downloaded repo"
  else
    echo-green "* cloning repository"
    git clone --recursive $WGET_URL $EXTRACTED_DIRNAME
  fi
  ;;
* )
  if [ -f "$DOWNLOAD_DIR/$WGET_DEST" ]; then
    echo-green "* using existing download:"
    echo "$(stat $DOWNLOAD_DIR/$WGET_DEST)"
    echo "md5sum: $(md5sum $DOWNLOAD_DIR/$WGET_DEST | cut -d' ' -f1)"
  else
    echo-green "* wget file"
    wget -c $WGET_URL -O $WGET_DEST
  fi
  ;;
esac

if [ $? -eq 0 ]; then
  echo-green "[download] succeeded"
else
  echo-red "[download] failed"
  exit 1
fi

