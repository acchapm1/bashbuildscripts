#!/bin/bash
set -o pipefail

source ../../header.source
source ../../module.source

#----------------------------------------------------------------------------#
# ./2_configure.sh                                                           #
# This script runs any necessary configuration scripts for installation.     #
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
# `_mpi_used` and `_compiler_used`. These are files that detect (from the    #
# variable $BUILD_DEPS + `module load`) what compiler/mpi is used.           #
# These files are used for proper placement of the software in 4_install.sh. #
# _install_dest is also created with the ultimate installation path.         #
#                                                                            #
# Also important are the $PRE_CONFIGURE_CMD and $POST_CONFIGURE_CMD.         #
# Sometimes, builds are more sophisicated than configure/make/install.       #
# If a file needs to be `patch`-ed, or `sed`-ed or files copied to different #
# directories (or ANYTHING), place those commands in this variable (using    #
# && as necessary) to ensure the full installation flow can be completed.    #
#----------------------------------------------------------------------------#

echo-green "[configure] started"
echo "* purging loaded modules"
module purge

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
  echo-red "[configure] failed"
  exit 1
fi

VARIABLES_SOURCE_PATH=$SCRATCH_ROOT/variables.source
source $VARIABLES_SOURCE_PATH
simple_error_check

for dep in "${BUILD_DEPS[@]}"
do
  # module loading success is determined by checking any stderr output
  # and grepping for `ERROR`; modules loaded may often give stderr
  # output that is not indicative of an error/informational, e.g., openmpi 
  echo "* loading module dependency: $dep"
  module load $dep &> $SCRATCH_ROOT/_configure_output
  if grep -q ERROR $SCRATCH_ROOT/_configure_output; then
    cat $SCRATCH_ROOT/_configure_output
    false; simple_error_check
  fi
done

COMPILER_USED="gcc-stock"
MPI_USED=""
if [ "$TARGET_PREFIX" = '/packages/uniform' ]; then
  case $PKGNAME in
    gcc | intel | pgi)
      #compiling a compiler for `uniform`
      echo-yellow "Compiling a compiler!"
      echo "$TARGET_PREFIX/arch/$MTUNE/compilers/$PKGNAME/${MODULE_VERSION:-$VERSION}" > $SCRATCH_ROOT/_install_dest
      ;;
    *)
      #compiling software for `uniform`, check deps to determine where it'll save to
      for dep in "${BUILD_DEPS[@]}"; do
        case "$dep" in
          gcc/* | intel/* | pgi/* )
            COMPILER_USED=${dep/\//-}
            break
            ;;
        esac
      done
      for dep in "${BUILD_DEPS[@]}"; do
        case "$dep" in
          mvapich2/* | openmpi/* | intel-mpi/* )
            MPI_USED=${dep/\//-}
            break
            ;;
        esac
      done
      echo-yellow "Compiling ordinary software!"
      export COMPILER_USED
      export MPI_USED
      export PACKAGE_BASEDIR="$TARGET_PREFIX/arch/$MTUNE/$COMPILER_USED"
      export PACKAGE_BASEDIR_STOCKGCC="$TARGET_PREFIX/arch/$MTUNE/gcc-stock"
      export PACKAGE_BASEDIR_STOCKGCC_BROADWELL="$TARGET_PREFIX/arch/broadwell/gcc-stock"
      export PACKAGE_BASEDIR_STOCKGCC_LOWEST="$TARGET_PREFIX/arch/broadwell/gcc-stock"
      source $VARIABLES_SOURCE_PATH
      echo "$TARGET_PREFIX/arch/$MTUNE/${COMPILER_USED}/$PKGNAME/${MODULE_VERSION:-$VERSION}" > $SCRATCH_ROOT/_install_dest
      ;;
  esac
  echo $COMPILER_USED > $SCRATCH_ROOT/_compiler_used
  echo $MPI_USED > $SCRATCH_ROOT/_mpi_used
  #needs a file rather than an export because new sbatch loses this value at step 5
else
  #Path taken by non-uniform (all uniform routes create _install_dest)
  export COMPILER_USED
  export MPI_USED
  echo $COMPILER_USED > $SCRATCH_ROOT/_compiler_used
  echo $MPI_USED > $SCRATCH_ROOT/_mpi_used
  export PACKAGE_BASEDIR="$TARGET_PREFIX"
  source $VARIABLES_SOURCE_PATH
  echo "$TARGET_PREFIX/$PKGNAME/${MODULE_VERSION:-$VERSION}" > $SCRATCH_ROOT/_install_dest
fi

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

#2.1
if [ ! -z "${PRE_CONFIGURE_CMD:-}" ]; then  #if not empty (existence/empty implied via ":-")
  echo-green "* running pre-configure command..."
  echo-command "  > $PRE_CONFIGURE_CMD"
  time eval $PRE_CONFIGURE_CMD 2>&1 | tee $SCRATCH_ROOT/_configure_output
  simple_error_check
fi

#2.2
if [ "${APPEND_CMAKE_INSTALL_PREFIX:-}" = true ]; then
  CONF_PREFIX="-DCMAKE_INSTALL_PREFIX=$INSTALL_DEST"
else
  CONF_PREFIX=""
fi

if [ ! -z "${CMAKE_ARGS:-$CONF_PREFIX}" ]; then  #if not empty (existence/empty implied via ":-")
  echo-green "* running cmake..."
  echo-command "  > cmake $CONF_PREFIX $CMAKE_ARGS $ADJUSTED_SRC"
  time cmake $CONF_PREFIX $CMAKE_ARGS $ADJUSTED_SRC 2>&1 | tee $SCRATCH_ROOT/_configure_output
  simple_error_check
fi

#2.3
if [ "${APPEND_PREFIX:-}" = true ]; then
  CONF_PREFIX=`cat $SCRATCH_ROOT/_install_dest`
  CONF_PREFIX="--prefix=$CONF_PREFIX"
else
  CONF_PREFIX=""
fi

if [ ! -z "${CONFIGURE_ARGS:-$CONF_PREFIX}" ]; then  #if not empty (existence/empty implied via ":-")
  echo-green "* running configure..."
  echo-command "  > $ADJUSTED_SRC/configure $CONF_PREFIX $CONFIGURE_ARGS"
  time $ADJUSTED_SRC/configure $CONF_PREFIX $CONFIGURE_ARGS 2>&1 | tee $SCRATCH_ROOT/_configure_output

  simple_error_check
fi

#2.4
if [ ! -z "${POST_CONFIGURE_CMD:-}" ]; then  #if not empty (existence/empty implied via ":-")
  echo-green "* running post-configure command..."
  echo-command "  > $POST_CONFIGURE_CMD"
  time eval $POST_CONFIGURE_CMD 2>&1 | tee $SCRATCH_ROOT/_configure_output
  simple_error_check
fi

if [ $? -eq 0 ]; then
  echo-green "[configure] succeeded"
else
  echo-red "[configure] failed"
  exit 1
fi

