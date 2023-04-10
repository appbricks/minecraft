#
# Deploy MyCD minecraft application 
# container as a service to docker
#

locals {
  minecraft_private_id = random_id.minecraft.hex
  minecraft_private_ip = "127.0.0.1"
}

resource "docker_container" "minecraft" {
  name  = local.minecraft_private_id
  image = docker_image.minecraft.image_id

  privileged = true
  restart    = "on-failure"

  # upload mycs-app config files to container
  dynamic "upload" {
    for_each = module.app-config.app_config_files
    content {
      file    = upload.key
      content = upload.value
    }
  }  
}

resource "docker_image" "minecraft" {
  name = (var.mycs_app_version == "dev" 
    ? "appbricks/minecraft-${var.minecraft_type}:dev"
    : "appbricks/minecraft-${var.minecraft_type}:${var.minecraft_version}"
  )
  keep_locally = true
}

resource "random_id" "minecraft" {
  prefix      = "${var.name}-"
  byte_length = 8
}
