variable "aws_profile" {
  description = "The AWS profile to use to authenticate"
  type        = string
  default     = "default"
}

variable "ec2_instance_type" {
  description = "The EC2 instance type to be launched"
  type        = string
  default     = "g4dn.xlarge"
}

variable "ec2_instance_volume_size" {
  description = "The size (in GB) of the root volume to attach to the EC2 instance"
  type        = number
  default     = 100
}

variable "ec2_instance_use_graphics_ami" {
  description = "Whether to launch the EC2 instance with the AMI with NVIDIA Tesla drivers preinstalled or to use the standard Amazon Linux 2 one"
  type        = bool
  default     = false
}
