#!/bin/bash -ex

root_dir=$(cd $(dirname $BASH_SOURCE)/.. && pwd)

cookbook_version=${VERSION:-dev}

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

if [[ $cookbook_version == dev* ]]; then
  $build_cookbook \
    --recipe ${root_dir}/cloud/recipes \
    --cookbook-name minecraft \
    --cookbook-desc "$cookbook_desc" \
    --cookbook-version $cookbook_version \
    --dest-dir "" \
    --template-only \
    --single \
    --verbose
else
  mycs_app_version=$(aws s3 ls s3://mycsprod-deploy-artifacts/releases/ | sort \
    | awk '/mycs-node-.*.zip/{ print $4 }' \
    | awk 'match($0, /[0-9]+\.[0-9]+\.[0-9]+/) { print substr($0, RSTART, RLENGTH) }' \
    | uniq | tail -1)

  for os_name in linux darwin windows; do
    for os_arch in amd64 arm64; do
      # build for all os architectures except for for windows/arm64
      if [[ $os_name != windows || $os_arch == amd64 ]]; then
        
        $build_cookbook \
          --recipe ${root_dir}/cloud/recipes \
          --cookbook-name minecraft \
          --cookbook-desc "$cookbook_desc" \
          --cookbook-version $cookbook_version \
          --dest-dir "" \
          --template-only \
          --single \
          --env-arg "mycs_app_version=${mycs_app_version}" \
          --os-name $os_name --os-arch $os_arch \
          --verbose
      fi
    done
  done
fi
