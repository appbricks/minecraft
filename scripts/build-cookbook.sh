#!/bin/sh -ex

root_dir=$(cd $(dirname $BASH_SOURCE)/.. && pwd)

cookbook_version=${VERSION:-0.0.0}

cookbook_build_dir=${root_dir}/.build/cookbook
cookbook_bin_dir=${cookbook_build_dir}/bin

[[ $1 != *:clean:* ]] || rm -fr $cookbook_build_dir
mkdir -p $cookbook_bin_dir

build_cookbook=${cookbook_bin_dir}/build-cookbook.sh

# Retrieve cookbook build scripts

if [[ ! -e $build_cookbook ]]; then
  curl -s -L https://raw.githubusercontent.com/appbricks/cloud-builder/master/scripts/build-cookbook.sh -o $build_cookbook
  chmod +x $build_cookbook
fi

cookbook_desc="This cookbook contains recipes to launch self-hosted minecraft servers."

$build_cookbook \
  --recipe ${root_dir}/cloud/recipes \
  --cookbook-name minecraft \
  --cookbook-desc "$cookbook_desc" \
  --cookbook-version $cookbook_version \
  --dest-dir "" \
  --template-only \
  --single \
  --verbose
