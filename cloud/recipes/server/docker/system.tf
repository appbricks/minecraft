#
# This template determines the characteristics
# of the underlying system the docker daemon is
# running in
#

locals {
  # directories start with "C:..." on Windows; All other OSs use "/" for root.
  is_windows = substr(pathexpand("~"), 0, 1) == "/" ? false : true

  # script file to retrieve local system environment variables
  env_script = local.is_windows ? "${path.cwd}/.terraform/env.ps1" : "${path.cwd}/.terraform/env.sh"
}

# Script to read local system environment
data "external" "system-env" {
  program = [ local.env_script ]
  depends_on = [ local_file.system-env-script ]
}

resource "local_file" "system-env-script" {
  content = (local.is_windows 
      ? <<PS_SCRIPT
ConvertTo-Json @{
  ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias Ethernet).IPAddress
  global_data_dir= $Env:ProgramData
  local_data_dir = $Env:LOCALAPPDATA
}
PS_SCRIPT
      : <<SH_SCRIPT
#!/bin/bash
cat <<EOF
{
  "ip": "$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)",
  "global_data_dir": "/usr/local/var/mycs",
  "local_data_dir": "$HOME/.mycs"
}
EOF
SH_SCRIPT
    )

  filename = local.env_script
}

output "ip" {
  value = data.external.system-env.result.ip
}

output "global_data_dir" {
  value = data.external.system-env.result.global_data_dir
}

output "local_data_dir" {
  value = data.external.system-env.result.local_data_dir
}
