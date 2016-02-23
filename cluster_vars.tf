variable "discovery_url" {}

variable "kube_version" {
  default = "v1.1.7"
}

variable "master_count" {
  default = 3
}

variable "worker_count" {
  default = 3
}
