#
# AWS specific resource names
#
# @resource_instance_list: aws_instance.minecraft
# @resource_instance_data_list: 
#

#
# AWS specific inputs
#

# The Minecraft VM's instance type
#
# @order: 20
# @tags: recipe,target-undeployed,target-deployed
# @accepted_values: t4g.nano,t4g.micro,t4g.small,t4g.medium,t4g.large,t4g.xlarge,t4g.2xlarge,t3a.nano,t3a.micro,t3a.small,t3a.medium,t3a.large,t3a.xlarge,t3a.2xlarge
# @accepted_values_message: Not a valid AWS general purpose AMD t4a.* or ARM t4g.* instance type
#
variable "minecraft_instance_type" {
  description = "The AWS EC2 instance type of the Minecraft server."
  default = "t4g.medium"
}
