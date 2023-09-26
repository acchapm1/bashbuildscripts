#!/bin/bash

if [ -z "$1" ]; then
  # if no argument provided to script, refresh /template/0.0.1/variables.source
  OUTPUTFILE=../../template/0.0.1/variables.source
  envsubst < ../../buildscripts/single/variables.source > $OUTPUTFILE;
else
  # if argument provided, source vars and update $PKGNAME's variables.source
  OUTPUTFILE=$1.new
  $(set -o allexport;
    source $1;
    set +o allexport;
    envsubst < ../../buildscripts/single/variables.source > $OUTPUTFILE;
   )
fi

# Default variables for envsubst

declare -A defaults

defaults["PKGNAME"]="package"
defaults["VERSION"]="0.0.1"

defaults["MAJOR"]="0"
defaults["MINOR"]="0"
defaults["PATCH"]="1"
defaults["MODULE_VERSION"]="\"\$VERSION\""

defaults["WGET_URL"]="\"https://example.org/download/\$MAJOR.\$MINOR/\$PKGNAME-\$VERSION.tar.gz\""
defaults["WGET_DEST"]="\"\$PKGNAME.tar.gz\""
defaults["GIT_COMMIT"]=""
defaults["EXTRACTED_DIRNAME"]="\"\$PKGNAME-\$VERSION\""

defaults["BUILD_DEPS"]="(\"\")"
defaults["RUNTIME_DEPS"]="(\"\")"
defaults["CONFLICT_DEPS"]=""

defaults["BUILD_IN_SRC_DIR"]=true
defaults["STEP_INTO_SUBDIR"]=""

# 2.1
defaults["PRE_CONFIGURE_CMD"]=""

# 2.2
defaults["CMAKE_ARGS"]=""
defaults["APPEND_CMAKE_INSTALL_PREFIX"]=false

# 2.3
defaults["CONFIGURE_ARGS"]=""
defaults["APPEND_PREFIX"]=true

# 2.4
defaults["POST_CONFIGURE_CMD"]=""

# 3.1a
defaults["ALTERNATE_BUILD_COMMAND"]=""

# 3.1b
defaults["MAKE_ARGS"]=""
defaults["MAKE_JOBS"]=""

# 3.2
defaults["MAKE_TARGETS"]="(\"\")"

# 4.1a
defaults["CONTENTS_TO_CP"]=""
defaults["DEST_SUBDIR"]=""
defaults["CP_ONLY_WHITELISTED_FILES"]="(\"\")"

# 4.1b
defaults["MAKE_INSTALL_ARGS"]=""
defaults["MAKE_INSTALL_APPEND_PREFIX"]=false
defaults["MAKE_PREFIX_LOWER_CASE"]=false

# MODULEFILE VARS
defaults["A2C2_TAGS"]=""
defaults["A2C2_DESCRIPTION"]=""
defaults["A2C2_URL"]=""
defaults["A2C2_NOTES"]=""

if [ -z "$1" ]; then
  # if no filename was provided, this is for the template

  for key in "${!defaults[@]}"
  do
    #echo "key  : $key"
    #echo "value: ${defaults[$key]}"
    if [ -z "${defaults[$key]}" ]; then
      sed -i -e "s|^$key.*|$key=\"\"|" $OUTPUTFILE
    else
      sed -i -e "s|^$key.*|$key=${defaults[$key]}|" $OUTPUTFILE
    fi
  done
else
  for key in "${!defaults[@]}"
  do
    #echo "key  : $key"
    #echo "value: ${defaults[$key]}"
    A=$(grep "^$key" $1)
    if [ -z "$A" ]; then
      # if key does not exist in original
      if [ -z "${defaults[$key]}" ]; then
        # and the value is still null, then add empty quotes
        sed -i -e "s|^$key.*|$key=\"\"|" $OUTPUTFILE
      else
        # use the default above
        sed -i -e "s|^$key.*|$key=${defaults[$key]}|" $OUTPUTFILE
      fi
    else
      # if key exists in original
      sed -i -e "s|^$key.*|$A|" $OUTPUTFILE
    fi
  done
fi

