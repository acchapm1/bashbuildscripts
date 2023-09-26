#!/bin/bash
set -o pipefail

source ../../header.source
source ../../module.source

#----------------------------------------------------------------------------#
# ./5_make_module.sh                                                         #
# This creates a module file in the respective environments' directory.      #
# For 6x/7x, this is /usr/share/Modules/modulefiles/[pkgname]/[version]      #
#                                                                            #
# For the uniform/ environment, it gets put into a separate directory tree.  #
# /packages/uniform/modulefiles/broadwell/intel-mpi (broadwell w/ intel-mpi) #
# /packages/uniform/modulefiles/skylake/gcc-stock (skylake w/ gcc-stock)     #
# /packages/uniform/modulefiles/phi/gcc-7.3.0 (phi w/ gcc-7.3.0 & so forth)  #
#                                                                            #
# This script does not need to be run as `root` (and preferably wouldn't)    #
# but is robust to fill the modulefile with the sudo'ed user.                #
#----------------------------------------------------------------------------#

echo-green "[module] started"
echo-yellow "* purging loaded modules"
module purge

source variables.source

if [ $# -eq 1 ]; then
  # an argument is provided; it's either a build_id or a v.s path
  re='^[0-9]+$'
  if ! [[ $1 =~ $re ]] ; then
    # it's not 100% numbers, so it'll be treated as a path
    VARIABLES_SOURCE_PATH=$1
    echo-green "* string provided; generating modulefile from $VARIABLES_SOURCE_PATH"
    source $VARIABLES_SOURCE_PATH
    simple_error_check
  else
    # its 100% numbers, so it'll be treated as a build_id
    BUILD_ID=$1
    echo-green "* using supplied build id... $BUILD_ID"
    SCRATCH_ROOT=/scratch/${SUDO_USER:-$USER}/builds/$PKGNAME/$BUILD_ID
    SRC_DIR=$SCRATCH_ROOT/src
  fi
else
  # no argument is provided; ascertaining build_id from symlinks
  if [ ! -e src ]; then
    echo-red "* existing symlink does not point to a valid scratch_root"
    false; simple_error_check
  fi
  BUILD_ID=$(readlink src | grep -Po '\/([0-9]+)\/' | sed 's#/##g' )
  echo-green "* using existing symlink for build id... $BUILD_ID"
  SCRATCH_ROOT=/scratch/${SUDO_USER:-$USER}/builds/$PKGNAME/$BUILD_ID
  SRC_DIR=$SCRATCH_ROOT/src
fi

if [ ! -z "${BUILD_ID:-}" ]; then
  # if build_id is set, access paths from scratch_root
  if [ ! -d "$SCRATCH_ROOT" ]; then
    # if scratch root doesn't exist, a bad build_id was provided or detectected
    echo-red "* cannot find existing source tree for provided build id."
    echo-red "[module] failed"
    exit 1
  fi

  INSTALL_DEST=`cat $SCRATCH_ROOT/_install_dest`
  simple_error_check
  COMPILER_USED=`cat $SCRATCH_ROOT/_compiler_used`
  simple_error_check
  MPI_USED=`cat $SCRATCH_ROOT/_mpi_used`
  simple_error_check

  VARIABLES_SOURCE_PATH=$SCRATCH_ROOT/variables.source
  source $VARIABLES_SOURCE_PATH
  simple_error_check
else
  ################################################################
  # build_id not set, get going on loading v.s variables!        #
  # This is the same as in 2_configure, but pruned down.         #
  # Be sure that changes here are reflected appropriately there. #
  ################################################################
  COMPILER_USED="gcc-stock"
  MPI_USED=""
  if [ "$TARGET_PREFIX" = '/packages/uniform' ]; then
    case $PKGNAME in
      gcc | intel | pgi)
        #compiling a compiler for `uniform`
        INSTALL_DEST="$TARGET_PREFIX/arch/$MTUNE/compilers/$PKGNAME/${MODULE_VERSION:-$VERSION}"
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
        export PACKAGE_BASEDIR="$TARGET_PREFIX/arch/$MTUNE/$COMPILER_USED"
        export PACKAGE_BASEDIR_STOCKGCC="$TARGET_PREFIX/arch/$MTUNE/gcc-stock"
        export PACKAGE_BASEDIR_STOCKGCC_BROADWELL="$TARGET_PREFIX/arch/broadwell/gcc-stock"
        export PACKAGE_BASEDIR_STOCKGCC_LOWEST="$TARGET_PREFIX/arch/broadwell/gcc-stock"
        source $VARIABLES_SOURCE_PATH
        INSTALL_DEST="$TARGET_PREFIX/arch/$MTUNE/${COMPILER_USED}/$PKGNAME/${MODULE_VERSION:-$VERSION}"
        ;;
    esac
  else
    #Path taken by non-uniform (all uniform routes create _install_dest)
    export PACKAGE_BASEDIR="$TARGET_PREFIX"
    source $VARIABLES_SOURCE_PATH
    INSTALL_DEST="$TARGET_PREFIX/$PKGNAME/${MODULE_VERSION:-$VERSION}"
  fi
  ################################################################
fi

echo-green "* creating module directory"
mkdir -p $MODULE_DIR/${PKGNAME}
MODULE_FILENAME=${MODULE_DIR}/${PKGNAME}/${MODULE_VERSION}

echo-green "* creating modulefile: $MODULE_FILENAME"
cat << EOT > $MODULE_FILENAME
#%Module1.0
proc ModulesHelp { } {
  puts stderr "${PKGNAME} ${MODULE_VERSION}"
}
module-whatis "${PKGNAME} ${MODULE_VERSION}"

EOT

case $PACKAGE_ENV in
6x)
  cat << EOT >> $MODULE_FILENAME
source \$env(MODULESHOME)/modulefiles/.required_functions
#source \$env(MODULESHOME)/modulefiles/.6xonly
#source \$env(MODULESHOME)/modulefiles/.7xonly
#source \$env(MODULESHOME)/modulefiles/.gui_warning
#source \$env(MODULESHOME)/modulefiles/.deprecated_warning
#source \$env(MODULESHOME)/modulefiles/.experimental_warning
#source \$env(MODULESHOME)/modulefiles/.discouraged_warning
#source \$env(MODULESHOME)/modulefiles/.retired_error

EOT
  ;;
7x)
  cat << EOT >> $MODULE_FILENAME
source \$env(MODULESHOME)/modulefiles/.required_functions
#source \$env(MODULESHOME)/modulefiles/.6xonly
#source \$env(MODULESHOME)/modulefiles/.7xonly
#source \$env(MODULESHOME)/modulefiles/.gui_warning
#source \$env(MODULESHOME)/modulefiles/.deprecated_warning
#source \$env(MODULESHOME)/modulefiles/.experimental_warning
#source \$env(MODULESHOME)/modulefiles/.discouraged_warning
#source \$env(MODULESHOME)/modulefiles/.retired_error

EOT
  ;;
*)
  cat << EOT >> $MODULE_FILENAME
source \$env(MODULESHOME)/modulefiles/.required_functions
#DeprecatedModule
#ExperimentalModule
#DiscouragedModule
#RetiredModule
#GuiModule
#WorksOnlyOnCentOS 7

EOT
  ;;
esac


for d in "${RUNTIME_DEPS[@]}"; do
    if [ ! -z "$d" ]; then
        echo "module load $d"
        echo "prereq $d"
    fi
done >> $MODULE_FILENAME

if [ -n "$CONFLICT_DEPS" ]; then
    echo ""
    echo "conflict $CONFLICT_DEPS"
    echo ""
fi >> $MODULE_FILENAME

echo "" >> $MODULE_FILENAME
echo "set topdir ${INSTALL_DEST}" >> $MODULE_FILENAME
echo "" >> $MODULE_FILENAME

if [ -d "${INSTALL_DEST}/bin" ]; then
    echo "prepend-path     PATH               \$topdir/bin"
else
    echo "#prepend-path    PATH               \$topdir/bin"
fi >> $MODULE_FILENAME

    echo "#prepend-path    CLASSPATH          \$topdir" >> $MODULE_FILENAME

if [ -d "${INSTALL_DEST}/lib" ]; then
    echo "prepend-path     LD_LIBRARY_PATH    \$topdir/lib"
else
    echo "#prepend-path    LD_LIBRARY_PATH    \$topdir/lib"
fi >> $MODULE_FILENAME

if [ -d "${INSTALL_DEST}/lib64" ]; then
    echo "prepend-path     LD_LIBRARY_PATH    \$topdir/lib64"
else
    echo "#prepend-path    LD_LIBRARY_PATH    \$topdir/lib64"
fi >> $MODULE_FILENAME

if [ -d "${INSTALL_DEST}/include" ]; then
    echo "prepend-path     INCLUDE            \$topdir/include"
else
    echo "#prepend-path    INCLUDE            \$topdir/include"
fi >> $MODULE_FILENAME

if [ -d "${INSTALL_DEST}/share/man" ]; then
    echo "prepend-path     MANPATH            \$topdir/share/man"
else
    echo "#prepend-path    MANPATH            \$topdir/share/man"
fi >> $MODULE_FILENAME

if [ -d "${INSTALL_DEST}/share/info" ]; then
    echo "prepend-path     INFOPATH           \$topdir/share/info"
else
    echo "#prepend-path    INFOPATH           \$topdir/share/info"
fi >> $MODULE_FILENAME

WHOIAM=$(whoami)
if (( EUID == 0 )); then
    WHOIAM=${SUDO_USER}
fi

echo "" >> $MODULE_FILENAME
case $PACKAGE_ENV in
6x)
  echo "SqlStoreModuleLoad N/A" >> $MODULE_FILENAME
  ;;
7x)
  echo "SqlStoreModuleLoad N/A" >> $MODULE_FILENAME
  ;;
*)
  echo "RecordModuleLoad ${PKGNAME} ${MODULE_VERSION} ${PACKAGE_ENV}" >> $MODULE_FILENAME
  ;;
esac

cat << EOT >> $MODULE_FILENAME

if { [module-info mode display] } {
    # A2C2 FIELDS
    setenv A2C2_6X "1"
    setenv A2C2_7X "1"
    setenv A2C2_NOLOGIN "0"
    setenv A2C2_DEPRECATED "0"
    setenv A2C2_EXPERIMENTAL "0"
    setenv A2C2_DISCOURAGED "0"
    setenv A2C2_RETIRED "0"
    setenv A2C2_VIRTUAL "0"

    setenv A2C2_TAGS "${A2C2_TAGS=-}"
    setenv A2C2_DESCRIPTION "${A2C2_DESCRIPTION=-}"
    setenv A2C2_URL "${A2C2_URL=-}"
    setenv A2C2_NOTES "${A2C2_NOTES=-}"

    setenv A2C2_INSTALL_DATE "$(date +%Y-%m-%d)"
    setenv A2C2_INSTALLER "$WHOIAM"
    setenv A2C2_BUILDPATH "/packages/uniform/build/${PKGNAME}/${VERSION}"

    setenv A2C2_MODIFY_DATE "$(date +%Y-%m-%d)"
    setenv A2C2_MODIFIER "$WHOIAM"

    setenv A2C2_VERIFY_DATE "$(date +%Y-%m-%d)"
    setenv A2C2_VERIFIER "$WHOIAM"
}

EOT

if [ $? -eq 0 ]; then
  echo-blue "be sure to edit $MODULE_FILENAME to add in tags/description and other metadata"
  echo-green "[module] succeeded"
else
  echo-red "[module] failed"
  exit 1
fi

