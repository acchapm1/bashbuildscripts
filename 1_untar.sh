#!/bin/bash

source ../../header.source
source ../../module.source
source variables.source

#----------------------------------------------------------------------------#
# ./1_untar.sh                                                               #
# This script extracts a downloaded archive $WGET_URL to $EXTRACTED_DIRNAME. #
# Extracts to a newly created location in your /scratch/$USER/builds dir.    #
#                                                                            #
# METHOD 1: Ideal for unattended builds                                      #
#                                                                            #
# $BUILD_ID - provided to script as first argument. This results in the      #
# creation of a separate build/src directory ../builds/[software]/12345      #
# By using a build_id, you can build the same piece of software/variants     #
# simultaneously without any interference on the filesystem.                 #
#                                                                            #
# 1_untar.sh is responsible for copying the variables.source (or variant)    #
# to the scratch directory for use.  Any changes to variables.source         #
# should either be done to the scratch/ dir version or re-run 1_untar.sh.    #
# TODO: determine smart way to copy back changes to version here to scratch/ #
#                                                                            #
# METHOD 2: Ideal for interactive building/creation of new modules           #
#                                                                            #
# When a $BUILD_ID is NOT provided, it will be randomly generated.           #
# This is ideal for simple, single, interactive builds (or testing v.s).     #
# As a convenience when not providing $BUILD_ID, three symlinks are created: #
# src/ -> points to the randomly generated directory containing source       #
# scratch/ -> dir that contains variables.source copy, $BUILD_DIR,           #
# and other text files (e.g., _mpi_used, _compiler_used) that are artifacts  #
# of builds but can be readily and safely deleted                            #
# variables.source -> allows easy editing/immediate feedback for changes     #
#----------------------------------------------------------------------------#

echo-green "[untar] started"

VARIABLES_SOURCE_PATH=variables.source
if [ $# -eq 1 ]; then
  BUILD_ID=$1
  echo-green "* using supplied build id... $BUILD_ID"
elif [ $# -eq 2 ]; then
  VARIABLES_SOURCE_PATH=$(readlink -e $2)
  BUILD_ID=$1
  echo-green "* using alternate variables.install: $2"
  echo-green "* using supplied build id... $BUILD_ID"
else
  ./9_rm_src.sh
  BUILD_ID=$RANDOM
  echo-green "* generating random build id... $BUILD_ID"
fi

if [ ! -f "$VARIABLES_SOURCE_PATH" ]; then
  echo-red "* variables.source could not be found, quitting!"
  exit 1
fi

if [ -z "$BUILD_ID" ]; then
  echo-red "* BUILD_ID could not be parsed, quitting!"
  exit 1
fi

SCRATCH_ROOT=/scratch/$USER/builds/$PKGNAME/$BUILD_ID
SRC_DIR=$SCRATCH_ROOT/src
echo-green "* creating scratch root: $SCRATCH_ROOT"
echo-command "  > mkdir -p $SCRATCH_ROOT"
mkdir -p $SCRATCH_ROOT
simple_error_check

if [ $# -eq 1 ] || [ $# -eq 2 ]; then
  echo-green "* copying $VARIABLES_SOURCE_PATH to $SCRATCH_ROOT"
  echo-command "  > cp $VARIABLES_SOURCE_PATH $SCRATCH_ROOT/variables.source"
  cp $VARIABLES_SOURCE_PATH $SCRATCH_ROOT/variables.source
  simple_error_check
  source $SCRATCH_ROOT/variables.source
  simple_error_check
else
  # user building out of normal build dir w/o build_id: symlink v.s instead!
  echo-green "* symlinking $VARIABLES_SOURCE_PATH to $SCRATCH_ROOT/variables.source"
  echo-command "  > ln -sfn $PWD/$VARIABLES_SOURCE_PATH $SCRATCH_ROOT/variables.source"
  ln -sfn $PWD/$VARIABLES_SOURCE_PATH $SCRATCH_ROOT/variables.source
  simple_error_check
fi

echo-green "* symlinking src/ to $SRC_DIR"
# kept as a convenience for getting to src since all scripts
# will actually go straight to /scratch through absolute dir
echo-command "  > ln -sfn $SRC_DIR $PWD/src"
ln -sfn $SRC_DIR $PWD/src

echo-green "* symlinking scratch/ to $SCRATCH_ROOT"
# kept as a convenience for getting to scratchroot since all scripts
# will actually go straight to /scratch through absolute dir
echo-command "  > ln -sfn $SCRATCH_ROOT $PWD/scratch"
ln -sfn $SCRATCH_ROOT $PWD/scratch

echo-green "* extracting $PKGNAME ($VERSION)"
case "$WGET_DEST" in
  *.tar.gz | *.tgz | *.bz2 | *.xz | *.tar | *.txz )
    echo-green "* verifying if archive has top-level directory first..."
    top_level_file_count=`tar -tf $DOWNLOAD_DIR/$WGET_DEST | grep -o '^[^/]\+' | sort -u | wc -l`
    if [ $top_level_file_count -eq 1 ]; then
      # only one file found, likely the organizational parent directory
      echo-command "  > tar xf $DOWNLOAD_DIR/$WGET_DEST -C $SCRATCH_ROOT"
      tar xf $DOWNLOAD_DIR/$WGET_DEST -C $SCRATCH_ROOT
    else
      # many files found, likely no parent directory
      echo-yellow "  - $top_level_file_count files found! This archive likely no parent directory container"
      echo-yellow "  - Forcing extracted files into \$EXTRACTED_DIR instead"
      echo-command "  > mkdir $SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION}"
      mkdir $SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION}
      echo-command "  > tar xf $DOWNLOAD_DIR/$WGET_DEST -C $SCRATCH_ROOT/$EXTRACTED_DIRNAME"
      tar xf $DOWNLOAD_DIR/$WGET_DEST -C $SCRATCH_ROOT/$EXTRACTED_DIRNAME
    fi
    ;;
  *.zip ) 
    echo-green "* verifying if archive has top-level directory first..."
    top_level_file_count=`zipinfo -1 $DOWNLOAD_DIR/$WGET_DEST | sed -r 's#([^/]+/).*#\1#' | sort -u | wc -l`
    if [ $top_level_file_count -eq 1 ]; then
      # only one file found, likely the organizational parent directory
      echo-command "  > unzip $DOWNLOAD_DIR/$WGET_DEST -d $SCRATCH_ROOT/$EXTRACTED_DIRNAME"
      unzip $DOWNLOAD_DIR/$WGET_DEST -d $SCRATCH_ROOT
      for d in $SCRATCH_ROOT/*/ ;do
        parent_dir=$(basename "$d")
        break
      done
      if [[ "$SCRATCH_ROOT/$parent_dir" -ef "$SCRATCH_ROOT/$EXTRACTED_DIRNAME" ]]; then
        echo-yellow "* extracted dir matches expected dir"
      else
        echo-command "  > mv $SCRATCH_ROOT/$parent_dir $SCRATCH_ROOT/$EXTRACTED_DIRNAME"
        mv $SCRATCH_ROOT/$parent_dir $SCRATCH_ROOT/$EXTRACTED_DIRNAME
      fi
    else
      # many files found, likely no parent directory
      echo-yellow "  - $top_level_file_count files found! This archive likely no parent directory container"
      echo-command "  > mkdir $SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION}"
      mkdir $SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION}
      echo-command "  > unzip $DOWNLOAD_DIR/$WGET_DEST -d $SCRATCH_ROOT/$EXTRACTED_DIRNAME"
      unzip $DOWNLOAD_DIR/$WGET_DEST -d $SCRATCH_ROOT/$EXTRACTED_DIRNAME
    fi
    ;;
  *.git )
    echo-command "  > cp -R $DOWNLOAD_DIR/$EXTRACTED_DIRNAME $SCRATCH_ROOT"
    cp -R $DOWNLOAD_DIR/$EXTRACTED_DIRNAME $SCRATCH_ROOT
    ;;
  *.sh )
    #shell script won't copy, e.g., anaconda2
    echo-command "  > mkdir $SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION}"
    mkdir $SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION}
    echo-command "  > touch $SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION}/dummyfile"
    touch $SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION}/dummyfile
    ;;
esac
simple_error_check

if [ -z "${EXTRACTED_DIRNAME:-}" ]; then
    echo-yellow "No extracted dirname entered (implying archive does not have a parent container)."
    echo-yellow "This is irregular, but not problematic."
    echo-yellow "This installation path should therefore use CP_ONLY_WHITELISTED_FILES="

    if [ -z "${CP_ONLY_WHITELISTED_FILES:-}" ]; then  #if val is empty empty (existence/empty implied via ":-")
        echo-yellow "Please fill in CP_ONLY_WHITELISTED_FILES to continue"
        exit 1
    else
        echo-green "* copying only whitelisted files..."
        echo-command "  > mkdir -p $SRC_DIR"
        mkdir -p $SRC_DIR
        for wlf in "${CP_ONLY_WHITELISTED_FILES[@]}"; do
            echo-command "  > cp ${SCRATCH_ROOT}/${wlf} $SRC_DIR/"
            cp ${SCRATCH_ROOT}/${wlf} $SRC_DIR/ 2>&1 | tee $SCRATCH_ROOT/_install_output
        done
    fi
else
    echo-green "* moving extracted dir to $SRC_DIR"
    echo-command "  > mv $SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION} $SRC_DIR"
    mv "$SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION}" $SRC_DIR
fi
simple_error_check

if [ ! -z "${GIT_COMMIT:-}" ]; then  #if not empty (existence/empty implied via ":-")
  if [ -d "$SRC_DIR/.git" ]; then
    CURRENT_COMMIT=$(git rev-parse HEAD)

    echo-green "* checking out commit: $GIT_COMMIT"
    echo-command "  > git reset --hard $GIT_COMMIT"
    cd $SRC_DIR
    time git reset --hard $GIT_COMMIT 2>&1 | tee $SCRATCH_ROOT/_untar_output
    simple_error_check
  else
    echo-yellow "* .git directory not found--likely .zip download; skipping commit checkout"
  fi
fi

if [ $? -eq 0 ]; then
  echo-green "[untar] succeeded"
else
  echo-red "[untar] failed"
  exit 1
fi

