variable "access_key" {}
variable "secret_key" {}

variable "ssh_public_key" {}
variable "ssh_private_key_path" {}

variable "region" {
  default = "eu-central-1"
}

variable "amis" {
  default = {
    eu-central-1 = "ami-ffafb293"
    eu-west-1 = "ami-c26bcab1"
    ap-northeast-1 = "ami-dae8c1b4"
    ap-southeast-1 = "ami-085a9a6b"
    ap-southeast-2 = "ami-eeadf58d"
    us-gov-west-1 = "ami-a98e33c8"
    sa-east-1 = "ami-4e981c22"
    us-east-1 = "ami-cbfdb2a1"
    us-west-1 = "ami-0eacc46e"
    us-west-2 = "	ami-16cfd277"
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
