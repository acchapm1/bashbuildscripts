#!/bin/bash
set -o pipefail

source ../../header.source
source ../../module.source

#----------------------------------------------------------------------------#
# ./4_install.sh                                                             #
# This should be the first script that actually creates files outside the    #
# source tree in the scratch/ directory.                                     #
#                                                                            #
# If it is a normal configure/make/make install, the installation directory  #
# has already been fed to the scripts and installed via `make install`.      #
# If it had an alternate build, or are in fact just archived binaries,       #
# then _install_dest is used to create the destdir and do the `cp` copy.     #
#                                                                            #
# $CONTENTS_TO_CP - This is any directory found within the $BUILD_DIR to     #
# more granularly choose what is copied to the install destination.          #
# $DEST_SUBDIR - Often binaries are shipped and just merely copied to the    #
# dest dir. $DEST_SUBDIR allows you to copy to additional directories so     #
# there is consistency for $PATH dirs. The most common value here might be   #
# '/bin', allowing the next step ./5_make_module.sh to automatically detect  #
# the directory and uncomment the PATH-PREPEND.                              #
# $CP_ONLY_WHITELISTED_FILES - allows individual copying of files in case    #
# the compiled binaries are not separated from the source tree with a simple #
# directory structure. Otherwise it's going to copy *.                       #
#                                                                            #
# In most circumstances, all the build process is completed by the time      #
# you get to ./4_install.sh.  In rare occasions, further building occurs     #
# which may fail for reasons unknown. In such cases, execute this script     #
# from `sudo -i` instead.                                                    #
#----------------------------------------------------------------------------#

echo-green "[install] started"
echo "* purging loaded modules"
modulecmd bash purge

source variables.source

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

if [ ! -d "$SCRATCH_ROOT" ]; then
  echo-red "* cannot find existing source tree for provided build id."
  echo-red "[install] failed"
  exit 1
fi

VARIABLES_SOURCE_PATH=$SCRATCH_ROOT/variables.source
source $VARIABLES_SOURCE_PATH
simple_error_check

for dep in "${BUILD_DEPS[@]}"
do
  echo "* loading module dependency: $dep"
  module load $dep &> $SCRATCH_ROOT/_install_output
  if grep -q ERROR $SCRATCH_ROOT/_install_output; then
    cat $SCRATCH_ROOT/_install_output
    false; simple_error_check
  fi
done

INSTALL_DEST=`cat $SCRATCH_ROOT/_install_dest`
simple_error_check

if [ ! -z "${STEP_INTO_SUBDIR:-}" ]; then  #if non-empty value (-z)
  ADJUSTED_SRC="$SRC_DIR/${STEP_INTO_SUBDIR}"
else
  ADJUSTED_SRC="$SRC_DIR"
fi

if [ ${BUILD_IN_SRC_DIR} = true ]; then
  BUILD_DIR=$ADJUSTED_SRC
else
  BUILD_DIR=$SCRATCH_ROOT/objdir
  echo-green "* creating build directory outside of source tree..."
  echo-command "  > mkdir -p $BUILD_DIR"
  mkdir -p $BUILD_DIR
  simple_error_check
fi

cd $BUILD_DIR
simple_error_check

#4.1
if [ ! -z "${CONTENTS_TO_CP:-}" ]; then  #if not empty (existence/empty implied via ":-")
  #4.1a
  INSTALL_DIR=`cat $SCRATCH_ROOT/_install_dest`
  if [ ! -z "${DEST_SUBDIR:-}" ]; then
    INSTALL_DIR="$INSTALL_DIR/${DEST_SUBDIR}"
  fi
  echo-green "* making dest directory..."
  echo-command "  > mkdir -p $INSTALL_DIR 2>&1"
  mkdir -p $INSTALL_DIR 2>&1 | tee $SCRATCH_ROOT/_install_output
  simple_error_check

  if [ ! -z "${CP_ONLY_WHITELISTED_FILES:-}" ]; then  #if not empty (existence/empty implied via ":-")
    echo-green "* copying only whitelisted files..."
    for wlf in "${CP_ONLY_WHITELISTED_FILES[@]}"; do
      echo "* install file: ${INSTALL_DIR}/${wlf}"
      echo-command "  > cp -R $BUILD_DIR/$CONTENTS_TO_CP/${wlf} $INSTALL_DIR/"
      cp -R $BUILD_DIR/$CONTENTS_TO_CP/${wlf} $INSTALL_DIR/ 2>&1 | tee $SCRATCH_ROOT/_install_output
    done
  else
    echo-green "* running cp -R install..."
    echo-command "  > cp -R $BUILD_DIR/$CONTENTS_TO_CP/* $INSTALL_DIR/"
    time cp -R $BUILD_DIR/$CONTENTS_TO_CP/* $INSTALL_DIR/ 2>&1 | tee $SCRATCH_ROOT/_install_output
  fi
  simple_error_check
else
  if [ "${MAKE_INSTALL_APPEND_PREFIX:-}" = true ]; then
    MAKE_PREFIX=`cat $SCRATCH_ROOT/_install_dest`
    if [ "${MAKE_PREFIX_LOWER_CASE:-}" = true ]; then
      MAKE_PREFIX="prefix=$MAKE_PREFIX"
    else
      MAKE_PREFIX="PREFIX=$MAKE_PREFIX"
    fi
  else
    MAKE_PREFIX=""
  fi

  #4.1b
  echo-green "* make install"
  echo-command "  > make ${MAKE_PREFIX} ${MAKE_INSTALL_ARGS:-} install"
  make ${MAKE_PREFIX} ${MAKE_INSTALL_ARGS:-} install 2>&1 | tee $SCRATCH_ROOT/_install_output
  simple_error_check
fi

if [ $? -eq 0 ]; then
  echo-green "[install] succeeded"
else
  echo-red "[install] failed"
  exit 1
fi

