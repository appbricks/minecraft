#!/bin/sh -ex

root_dir=$(cd $(dirname $BASH_SOURCE)/.. && pwd)

cookbook_dir=${root_dir}/.build/cookbook
cookbook_bin_dir=${cookbook_dir}/bin
mkdir -p $cookbook_bin_dir

build_cookbook=${cookbook_bin_dir}/build-cookbook.sh

# Retrieve cookbook build scripts

if [[ ! -e $build_cookbook ]]; then
  curl -s -L https://raw.githubusercontent.com/appbricks/cloud-builder/master/scripts/build-cookbook.sh -o $build_cookbook
  chmod +x $build_cookbook
fi

$build_cookbook -r ${root_dir}/cloud/recipes -d "" -b dev -s -v
