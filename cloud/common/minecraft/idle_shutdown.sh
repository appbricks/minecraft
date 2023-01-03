#!/bin/bash

set -e

if [[ "${mc_type}" != "bedrock" ]]; then
  GET_CONNECTED_USERS=$(cat <<EOF
from mcstatus import JavaServer
server = JavaServer.lookup("localhost:${mc_port}")
status = server.status()
print(status.players.online)
EOF
)
else
  GET_CONNECTED_USERS=$(cat <<EOF
from mcstatus import BedrockServer
server = BedrockServer.lookup("localhost:19132")
status = server.status()
print(status.players_online)
EOF
)
fi

num_connected_clients=$(python3 -c "$GET_CONNECTED_USERS")

shutdown_counter=${mc_root}/logs/shutdown_countdown
counter=$([[ -e $shutdown_counter ]] && cat $shutdown_counter || echo 10)
if [[ $num_connected_clients -eq 0 ]]; then
  counter=$((counter-1))
else
  counter=10
fi
if [[ $counter -gt 0 ]]; then
  echo "$counter" > $shutdown_counter
else
  rm $shutdown_counter
  echo $(date +"%Y-%m-%d %H:%M:%S")' Shutting down instance due to inactivity...' >> ${mc_root}/logs/shutdown.log
  sudo shutdown now
fi
