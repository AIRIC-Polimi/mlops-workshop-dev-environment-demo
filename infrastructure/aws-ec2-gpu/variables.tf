variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

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
