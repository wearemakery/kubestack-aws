# Kubestack AWS

Provision a Kubernetes cluster with [Terraform](https://www.terraform.io) and [CoreOS](https://coreos.com/) on AWS. The provisioning mimics the original documentation: [Manual Installation](https://coreos.com/kubernetes/docs/latest/getting-started.html) as close as possible.

## Main features

1. The script follows Kubernetes best practices and embody the "CoreOS Way"

  * Components secured with TLS
  * Individual node can reboot and the cluster will still function
  * Internal cluster DNS is available
  * Service accounts enabled
  * Cloud-provider enabled

2. Moving parts can be customized

  * AWS region
  * Master and worker instance types
  * Master and worker disk sizes
  * Master and worker node counts
  * Kubernetes version

## Requirements

* Terraform
* OpenSSL 
* Kubernetes-cli (kubectl)
* AWS account / [security credential](https://console.aws.amazon.com/iam/home?#security_credential) / [key pair](http://docs.aws.amazon.com/gettingstarted/latest/wah/getting-started-prereq.html#create-a-key-pair)

## Setup

* create a file: `terraform.tfvars`

```
# aws
access_key = "<access key>"
secret_key = "<secret key>"

ssh_public_key = "<ssh public key>"
ssh_private_key_path = "<path to private key file>"

# generate new discovery url: https://discovery.etcd.io/new?size=<master_count>
discovery_url = "<discovery url>"

# cluster
master_count = 1
worker_count = 1
```

* create cluster

```
terraform plan
terraform apply
```

* check nodes

```
kubectl get nodes
```
