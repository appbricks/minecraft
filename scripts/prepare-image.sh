#!/bin/bash
#
# Install, configure and start a new Minecraft server

set -xeu

MC_ROOT=/opt/minecraft
mkdir -p $MC_ROOT

MINECRAFT_JAR="minecraft_server.jar"
JAVA_MX_MEM=${java_mx_mem:-}
JAVA_MS_MEM=${java_ms_mem:-}

BEDROCK_SERVER="bedrock_server"
BEDROCK_VERSION=${mc_version:-"1.19.51.01"}

download_minecraft_server() {
  WGET=$(which wget)

  [[ "${mc_type}" == bedrock ]] || \
    apt-get -yq install \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confold" \
      openjdk-17-jre-headless

  # version_manifest.json lists available MC versions
  $WGET -O ${MC_ROOT}/version_manifest.json https://launchermeta.mojang.com/mc/game/version_manifest.json
  if [[ "${mc_type}" == "vanilla" || "${mc_type}" == "paper" ]]; then
    if [[ -z "${mc_version}" ]]; then
      echo "ERROR! For 'vanilla' or 'paper' distribution types a version must be provided."
      exit 1
    fi
    MC_VERSION=${mc_version}
    if [[ "${mc_version}" == "latest" ]]; then
      # Find latest version number if user wants that version (the default)
      MC_VERSION=$(jq -r '.["latest"]["release"]' ${MC_ROOT}/version_manifest.json)
    fi
    DOWNLOAD_URL=https://appbricks-public-downloads.s3.amazonaws.com/minecraft/releases/${mc_type}_${MC_VERSION}.zip
  elif [[ "${mc_type}" == "bedrock" ]]; then
    DOWNLOAD_URL=https://minecraft.azureedge.net/bin-linux/bedrock-server-${BEDROCK_VERSION}.zip
  else
    DOWNLOAD_URL=https://appbricks-public-downloads.s3.amazonaws.com/minecraft/releases/${mc_type}.zip
  fi

  set +e
  $WGET -O ${MC_ROOT}/minecraft_distro.zip $DOWNLOAD_URL
  if [[ $? != 0 ]]; then
    set -e
    if [[ "${mc_type}" == "vanilla" ]]; then
      # Index version_manifest.json by the version number and extract URL for the specific version manifest
      VERSIONS_URL=$(jq -r '.["versions"][] | select(.id == "'"${MC_VERSION}"'") | .url' ${MC_ROOT}/version_manifest.json)
      # From specific version manifest extract the vanilla server JAR URL
      VANILLA_SERVER_URL=$(curl -s $VERSIONS_URL | jq -r '.downloads | .server | .url')
      # And finally download it to our local MC dir
      $WGET -O ${MC_ROOT}/${MINECRAFT_JAR} $VANILLA_SERVER_URL
    else
      echo "ERROR! Distribution package '${mc_type}' not found at download URL '${DOWNLOAD_URL}'"
      exit 1
    fi
  else
    set -e
    cd ${MC_ROOT}
    unzip ${MC_ROOT}/minecraft_distro.zip
    if [[ -e ./world ]]; then
      zip -r ./world.zip ./world
      rm -fr ./world
    fi
    cd -
  fi
  rm -f ${MC_ROOT}/minecraft_distro.zip

  /bin/cat >${MC_ROOT}/eula.txt<< ---EOT
eula=true
---EOT
}

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get -yq install \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  wget unzip

download_minecraft_server

/bin/cat >${MC_ROOT}/run_server.sh<< ---EOT
#!/bin/bash

cd ${MC_ROOT}
if [[ -e ./world.zip ]]; then
  unzip ./world.zip
  rm world.zip
fi

---EOT

if [[ "${mc_type}" == "bedrock" ]]; then

  /bin/cat >>${MC_ROOT}/run_server.sh<< ---EOT
LD_LIBRARY_PATH=${MC_ROOT} \\
  ${MC_ROOT}/${BEDROCK_SERVER}
---EOT

else

  /bin/cat >>${MC_ROOT}/run_server.sh<< ---EOT
mc_description=\${1:-My awesome minecraft worlds in the cloud.}
mc_port=\${2:-25565}
---EOT

  # set server description
  if [[ "${mc_type}" == "vanilla" || "${mc_type}" == "paper" ]]; then
    if [[ -e "${MC_ROOT}/server.properties" ]]; then
      /bin/cat >>${MC_ROOT}/run_server.sh<< ---EOT
sed -i -E "s|motd=.*|motd=\${mc_description}|" ${MC_ROOT}/server.properties
sed -i -E "s|server-port=.*|server-port=\${mc_port}|" ${MC_ROOT}/server.properties
---EOT
    else
      /bin/cat >>${MC_ROOT}/run_server.sh<< ---EOT
echo "motd=\${mc_description}" > ${MC_ROOT}/server.properties
echo "server-port=\${mc_port}" >> ${MC_ROOT}/server.properties
---EOT
    fi
  fi

  /bin/cat >>${MC_ROOT}/run_server.sh<< ---EOT

java_mx_mem=\${3:-2g}
java_ms_mem=\${4:-2g}
/usr/bin/java -Xmx\${java_mx_mem} -Xms\${java_ms_mem} -jar $MINECRAFT_JAR nogui
---EOT

fi

chmod +x ${MC_ROOT}/run_server.sh
