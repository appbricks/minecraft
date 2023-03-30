#!/bin/bash

set -eu

root_dir=$(cd $(dirname $BASH_SOURCE)/.. && pwd)

java_version=18
via_version=4.2.1

mc_server_type=vanilla
mc_server_version=latest

mc_build_type=_NA_
mc_svr_props_path=
mc_svr_map_path=

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--type)
      mc_server_type=$2
      shift
      ;;
    -v|--version)
      mc_server_version=$2
      shift
      ;;
    -b|--build-type)
      mc_build_type=$2
      shift
      ;;
    -d|--debug)
      set -x
      ;;
    *)
      echo -e "ERROR! Unknown option \"$1\"."
      exit 1
      ;;
  esac
  shift
done

releases_dir=${root_dir}/.releases
mkdir -p $releases_dir

# Retrieve vanilla minecraft versions manifest
vanilla_server_manifest=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json)
# Determine actual version number
if [[ $mc_server_version == latest ]]; then
  vanilla_latest_version=$(echo "$vanilla_server_manifest" | jq -r '.["latest"]["release"]')
  mc_ver=$vanilla_latest_version
else
  mc_ver=$mc_server_version
fi

config_dir=${root_dir}/config/${mc_build_type}
if [[ -e ${config_dir}/build-properties ]]; then
  source ${config_dir}/build-properties
  [[ ! -e ${config_dir}/server.properties ]] || mc_svr_props_path=${config_dir}/server.properties

  # download server resources (i.e. maps etc)  
  download_dir=${root_dir}/.downloads/${mc_build_type}
  rm -fr $download_dir
  mkdir -p $download_dir

  set +e
  aws s3 cp \
    s3://appbricks-public-downloads/minecraft/maps/${mc_build_type}.zip \
    ${download_dir}/map.zip 2>&1 >/dev/null
  [[ ! -e ${download_dir}/map.zip ]] || \
    mc_svr_map_path=${download_dir}/map.zip
  set -e

  mc_release_name=$mc_build_type
else
  mc_release_name=${mc_server_type}_${mc_ver}
fi

# Index version_manifest.json by the version number and extract URL for the specific version manifest
vanilla_versions_metadata_url=$(echo "$vanilla_server_manifest" | jq -r '.["versions"][] | select(.id == "'"$mc_ver"'") | .url')

# Validate current java version
vanilla_server_java_version=$(curl -s $vanilla_versions_metadata_url | jq -r '.javaVersion.majorVersion')
[[ $java_version == $vanilla_server_java_version ]] || \
  (echo "WARNING! Minecraft version ${mc_ver} requires java ${vanilla_server_java_version}, but build java version is set as ${java_version}.")
current_java_version=$(java -version 2>&1 | awk -F'[ "]' '/ version/{ split($4,v,"."); print v[1] }')
[[ $current_java_version == $java_version ]] || \
  (echo "ERROR! Need Java SDK version $java_version for build."; exit 1)

build_dir=${root_dir}/.build
server_build=${build_dir}/${mc_release_name}
rm -fr $server_build
mkdir -p $server_build

case $mc_server_type in
  vanilla)
    echo "Downloading vanilla minecraft server version ${mc_ver}..."

    # From specific version manifest extract the server JAR URL
    vanilla_server_url=$(curl -s $vanilla_versions_metadata_url | jq -r '.downloads | .server | .url')

    curl -s \
      -L $vanilla_server_url \
      -o ${server_build}/minecraft_server.jar
    ;;

  paper)
    echo "Downloading paper minecraft server version ${mc_ver}..."
    
    set +e
    paper_builds=$(curl -s -f https://api.papermc.io/v2/projects/paper/versions/${mc_ver})
    [[ -n $paper_builds ]] || (echo "ERROR! Invalid version."; exit 1)
    set -e
    paper_build_num=$(echo $paper_builds | jq '.builds | sort | last')

    curl -s \
      -L https://api.papermc.io/v2/projects/paper/versions/${mc_ver}/builds/${paper_build_num}/downloads/paper-${mc_ver}-${paper_build_num}.jar \
      -o ${server_build}/minecraft_server.jar
    ;;
  *)
    echo -e "ERROR! Unhandled server type \"$mc_server_type\"."
    exit 1
    ;;
esac

echo "Creating server files..."
pushd $server_build 2>&1 >/dev/null
java -Xms2G -Xmx2G -XX:+UseG1GC -jar minecraft_server.jar nogui 2>&1 >/dev/null
popd 2>&1 >/dev/null

[[ -z $mc_svr_props_path ]] || cp $mc_svr_props_path $server_build

if [[ -n $mc_svr_map_path ]]; then
  echo "Extracting custom map for $mc_build_type..."
  rm -fr ${server_build}/world 
  mkdir ${server_build}/world
  pushd ${server_build}/world 2>&1 >/dev/null
  unzip $mc_svr_map_path
  popd 2>&1 >/dev/null

  if [[ -e ${server_build}/world/resources.zip ]]; then
    echo "Uploading resources..."
    aws s3 cp ${server_build}/world/resources.zip s3://appbricks-public-downloads/minecraft/resource-packs/${mc_build_type}.zip
    PAGER= aws s3api put-object-acl --acl public-read --bucket appbricks-public-downloads --key minecraft/resource-packs/${mc_build_type}.zip

    if [[ `uname` == Darwin ]]; then
      sha1sum=$(shasum ${server_build}/world/resources.zip | awk '{print $1}')
    else
      sha1sum=$(sha1sum ${server_build}/world/resources.zip)
    fi

    cat << ---EOF >> ${server_build}/server.properties
resource-pack=https://appbricks-public-downloads.s3.amazonaws.com/minecraft/resource-packs/${mc_build_type}.zip
resource-pack-sha1=${sha1sum}
---EOF

    rm -f ${server_build}/world/resources.zip
  fi
fi
if [[ $mc_server_type == paper ]]; then
  mkdir -p ${server_build}/plugins

  echo "Adding Geyser plugin to allow BedRock clients to connect..."
  curl -s \
    -L https://ci.opencollab.dev/job/GeyserMC/job/Geyser/job/master/lastSuccessfulBuild/artifact/bootstrap/spigot/target/Geyser-Spigot.jar \
    -o ${server_build}/plugins/Geyser-Spigot.jar

  if [[ $mc_server_version != latest ]]; then
    echo "Adding ViaVersion plugin to allow latest clients connect to server version ${mc_ver}..."
    curl -s \
      -L https://appbricks-public-downloads.s3.amazonaws.com/ViaVersion-${via_version}.jar \
      -o ${server_build}/plugins/ViaVersion.jar
  fi
fi

echo "Creating release"
release_file_path=${releases_dir}/${mc_release_name}.zip
rm -f $release_file_path
pushd $server_build 2>&1 >/dev/null
zip -r $release_file_path .
popd 2>&1 >/dev/null

echo "Uploading release"
aws s3 cp $release_file_path s3://appbricks-public-downloads/minecraft/releases/${mc_release_name}.zip
PAGER= aws s3api put-object-acl --acl public-read --bucket appbricks-public-downloads --key minecraft/releases/${mc_release_name}.zip
