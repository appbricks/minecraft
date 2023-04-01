#
# MyCS Application configuration
#

locals {
  # mycs_app_config_dir = "${data.external.system-env.result.global_data_dir}/minecraft/${var.minecraft_type}_${var.minecraft_version}/etc"
}

module "app-config" {
  source = "github.com/appbricks/cloud-inceptor.git/modules/app-config"

  mycs_cloud_public_key_id = var.mycs_cloud_public_key_id
  mycs_cloud_public_key = var.mycs_cloud_public_key
  mycs_app_private_key = var.mycs_app_private_key
  mycs_app_id_key = var.mycs_app_id_key
  mycs_app_version = var.mycs_app_version
  mycs_space_ca_root = var.cb_root_ca_cert

  app_work_directory = local.minecraft_root
  app_exec_cmd = "${local.minecraft_root}/run_server.sh"
  app_cmd_arguments = (var.minecraft_type == "bedrock" 
    ? [
      var.minecraft_server_description,
    ] 
    : [ 
      var.minecraft_server_description,
      var.minecraft_port,
      var.java_mx_mem,
      var.java_ms_mem
    ]
  )

  app_description = "Minecraft Server (${var.minecraft_type})"
  app_domain_name = "${var.name}.${var.cb_internal_domain}"
  app_service_ports = jsonencode([
    {
      "name": "server"
      "port": var.minecraft_type == "bedrock" ? 19132 : var.minecraft_port
    }
  ])
  
  depends_on = [
    data.external.system-env
  ]
}
