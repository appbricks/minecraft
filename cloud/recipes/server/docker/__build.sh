#!/bin/bash

target_os=${1:-}
target_arch=${2:-}
cookbook_version=${3:-}

recipe_dir=$(cd $(dirname $BASH_SOURCE) && pwd)

set -xeuo pipefail

download_dir=`mktemp -d`

cookbook_utils_version="0.0.0"

if [[ $cookbook_version == dev* ]]; then
  curl -f -s \
    -L https://mycsdev-deploy-artifacts.s3.amazonaws.com/releases/mycs-cookbook-utils_${target_os}_${target_arch}.zip \
    -o ${download_dir}/mycs-cookbook-utils.zip
else
  curl -f -s \
    -L https://mycsprod-deploy-artifacts.s3.amazonaws.com/releases/mycs-cookbook-utils-${cookbook_utils_version}_${target_os}_${target_arch}.zip \
    -o ${download_dir}/mycs-cookbook-utils.zip
fi
cd ${download_dir}
unzip ./mycs-cookbook-utils.zip
cd -

# remove any downloaded windows binaries from 
# previous build if any and refresh repo
rm -f ${recipe_dir}/system-env*
if [[ $target_os == windows ]]; then
  mv ${download_dir}/system-env.exe ${recipe_dir}
else
  mv ${download_dir}/system-env ${recipe_dir}
fi

rm -fr $download_dir
