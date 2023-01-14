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
  name         = "appbricks/minecraft-${var.minecraft_type}/latest"
  keep_locally = true
}

resource "random_id" "minecraft" {
  prefix      = "mc-"
  byte_length = 8
}

# # Create a docker image resource
# # -> docker pull nginx:latest
# resource "docker_image" "nginx" {
#   name         = "nginx:latest"
#   keep_locally = true
# }

# # Create a docker container resource
# # -> same as 'docker run --name nginx -p8080:80 -d nginx:latest'
# resource "docker_container" "nginx" {
#   name    = "nginx"
#   image   = docker_image.nginx.image_id

#   ports {
#     external = 8080
#     internal = 80
#   }
# }
