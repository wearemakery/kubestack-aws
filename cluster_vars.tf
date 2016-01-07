variable "discovery_url" {}

variable "kube_version" {
  default = "v1.1.3"
}

variable "master_count" {
  default = 1
}

variable "worker_count" {
  default = 1
}
