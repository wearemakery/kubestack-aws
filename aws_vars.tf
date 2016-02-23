variable "access_key" {}
variable "secret_key" {}

variable "ssh_public_key" {}
variable "ssh_private_key_path" {}

variable "region" {
  default = "eu-central-1"
}

variable "amis" {
  default = {
    eu-central-1 = "ami-15190379"
    eu-west-1 = "ami-2a1fad59"
    ap-northeast-1 = "ami-02c9c86c"
    ap-southeast-1 = "ami-00a06963"
    ap-southeast-2 = "ami-949abdf7"
    us-gov-west-1 = "ami-e0b70b81"
    sa-east-1 = "ami-c40784a8"
    us-east-1 = "ami-7f3a0b15"
    us-west-1 = "ami-a8aedfc8"
    us-west-2 = "ami-4f00e32f"
  }
}

variable "master_instance_type" {
  default = "t2.small"
}

variable "worker_instance_type" {
  default = "m3.xlarge"
}

variable "master_volume_size" {
  default = 25
}

variable "worker_volume_size" {
  default = 250
}
