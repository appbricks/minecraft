#
# MyCS Application configuration
#

module "app-config" {
  source = "github.com/appbricks/cloud-inceptor.git/modules/app-config"

  mycs_cloud_public_key_id = var.mycs_cloud_public_key_id
  mycs_cloud_public_key = var.mycs_cloud_public_key
  mycs_app_private_key = var.mycs_app_private_key
  mycs_app_id_key = var.mycs_app_id_key
  mycs_app_version = var.mycs_app_version
  mycs_space_ca_root = var.cb_root_ca_cert

  app_file_archive = "${path.module}/.minecraft-app-scripts.zip"
  app_install_script_name = "install.sh"

  depends_on = [
    data.archive_file.minecraft-app-scripts
  ]
}

#
# Applications Scripts
#

data "archive_file" "minecraft-app-scripts" {
  type        = "zip"
  output_path = "${path.module}/.minecraft-app-scripts.zip"

  source {
    content  = "${data.template_file.minecraft-install.rendered}"
    filename = "install.sh"
  }

  source {
    content  = "${data.template_file.minecraft-idle-shutdown.rendered}"
    filename = "idle_shutdown.sh"
  }

  source {
    content  = "${data.template_file.minecraft-update-dns.rendered}"
    filename = "update_dns.sh"
  }
}

data "template_file" "minecraft-install" {
  template = file("${path.module}/install.sh")

  vars = {
    mc_description = var.minecraft_server_description

    mc_root        = local.minecraft_root
    mc_version     = var.minecraft_version
    mc_type        = var.minecraft_type
    mc_port        = var.minecraft_port
    mc_backup_freq = var.minecraft_backup_frequency

    java_mx_mem    = var.java_mx_mem
    java_ms_mem    = var.java_ms_mem

    mc_bucket      = aws_s3_bucket.minecraft.bucket
  }
}

data "template_file" "minecraft-idle-shutdown" {
  template = file("${path.module}/idle_shutdown.sh")

  vars = {
    mc_root = local.minecraft_root
    mc_type = var.minecraft_type
    mc_port = var.minecraft_port
  }
}

data "template_file" "minecraft-update-dns" {
  template = file("${path.module}/update_dns.sh")

  vars = {
    mc_dns_name    = "${var.name}.${var.cb_internal_domain}"
    dns_zone       = var.cb_internal_domain
    pdns_url       = var.cb_internal_pdns_url
    pdns_api_key   = var.cb_internal_pdns_api_key
  }
}
