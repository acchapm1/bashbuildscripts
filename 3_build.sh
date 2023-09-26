#!/bin/bash
set -o pipefail

source ../../header.source
source ../../module.source

#----------------------------------------------------------------------------#
# ./3_build.sh                                                               #
# This script actually builds the software with the appropriate `make`.      #
# It supports the use of ./configure as well as cmake.                       #
#                                                                            #
# $BUILD_IN_SRC_DIR - more often than not, you can successfully and safely   #
# build software in the source tree itself. There are some exceptions where  #
# a clean source dir is required, and if this is set to `false`, it will     #
# create the scratch-located `obj_dir/` directory.                           #
#                                                                            #
# This script will execute `cmake` and `configure` (in that order) provided  #
# that they are flagged to run. An empty variable ("") indicates the step    #
# will be skipped.  However, $APPEND_CMAKE_INSTALL_PREFIX and                #
# $APPEND_PREFIX automatically enable each respective process.               #
#                                                                            #
# This script also creates (in the scratch dir) a number of side-files.      #
# _mpi_used and _compiler_used.  These are files that detect (based on the   #
# dependencies loaded through `module load`) what compiler/mpi is used.      #
# These files are used for proper placement of the software in 4_install.sh. #
# _install_dest is also created with the ultimate installation path.         #
#----------------------------------------------------------------------------#

echo-green "[build] started"
echo "* purging loaded modules"
modulecmd bash purge

source variables.source

if [ $# -eq 1 ]; then
  BUILD_ID=$1
  echo-green "* using supplied build id... $BUILD_ID"
  SCRATCH_ROOT=/scratch/$USER/builds/$PKGNAME/$BUILD_ID
  SRC_DIR=$SCRATCH_ROOT/src
else
  BUILD_ID=$(readlink src | grep -Po '\/([0-9]+)\/' | sed 's#/##g' )
  echo-green "* using existing symlink for build id... $BUILD_ID"
  SCRATCH_ROOT=/scratch/$USER/builds/$PKGNAME/$BUILD_ID
  SRC_DIR=$SCRATCH_ROOT/src
fi

if [ ! -d "$SCRATCH_ROOT" ]; then
  echo-red "* cannot find existing source tree for provided build id."
  echo-red "[build] failed"
  exit 1
fi

VARIABLES_SOURCE_PATH=$SCRATCH_ROOT/variables.source
source $VARIABLES_SOURCE_PATH
simple_error_check

for dep in "${BUILD_DEPS[@]}"
do
  echo "* loading module dependency: $dep"
  module load $dep &> $SCRATCH_ROOT/_build_output
  if grep -q ERROR $SCRATCH_ROOT/_build_output; then
    cat $SCRATCH_ROOT/_build_output
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

#3.1
if [ ! -z "${ALTERNATE_BUILD_COMMAND:-}" ]; then  #if not empty (existence/empty implied via ":-")
  #3.1a
  echo-green "* running alternate build command..."
  echo-command "  > $ALTERNATE_BUILD_COMMAND"
  time eval $ALTERNATE_BUILD_COMMAND 2>&1 | tee $SCRATCH_ROOT/_build_output
  simple_error_check
else
  #3.1b
  CONCURRENT_JOBS=${MAKE_JOBS:--j $MAKE_SIMUL_JOBS}
  echo-green "* running make (concurrency: $CONCURRENT_JOBS)"
  echo-command "  > make ${MAKE_ARGS:-} $CONCURRENT_JOBS"
  time make ${MAKE_ARGS:-} $CONCURRENT_JOBS 2>&1 | tee $SCRATCH_ROOT/_build_output
  simple_error_check
fi

#3.2
if [ ! -z "${MAKE_TARGETS:-}" ]; then
  for dep in "${MAKE_TARGETS[@]}"
  do
    echo-yellow "* running additional make target: $dep"
    echo-command "  > make $dep"
    time make $dep 2>&1 | tee $SCRATCH_ROOT/_build_output
    simple_error_check
  done
fi

if [ $? -eq 0 ]; then
  echo-green "[build] succeeded"
else
  echo-red "[build] failed"
  exit 1
fi

