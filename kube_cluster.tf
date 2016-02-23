provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

resource "aws_iam_role" "master_role" {
  name = "master_role"
  assume_role_policy = "${file("iam/kubernetes-master-role.json")}"
}

resource "aws_iam_role_policy" "master_policy" {
  name = "master_policy"
  role = "${aws_iam_role.master_role.id}"
  policy = "${file("iam/kubernetes-master-policy.json")}"
}

resource "aws_iam_instance_profile" "master_profile" {
  name = "master_profile"
  roles = ["${aws_iam_role.master_role.name}"]
}

resource "aws_iam_role" "worker_role" {
  name = "worker_role"
  assume_role_policy = "${file("iam/kubernetes-worker-role.json")}"
}

resource "aws_iam_role_policy" "worker_policy" {
  name = "worker_policy"
  role = "${aws_iam_role.worker_role.id}"
  policy = "${file("iam/kubernetes-worker-policy.json")}"
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "worker_profile"
  roles = ["${aws_iam_role.worker_role.name}"]
}

resource "aws_security_group" "kube_cluster" {
  name = "kube-cluster"
  description = "Kubernetes cluster"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 2379
    to_port = 2380
    protocol = "TCP"
    self = true
  }

  ingress {
    from_port = 4001
    to_port = 4001
    protocol = "TCP"
    self = true
  }

  ingress {
    from_port = 7001
    to_port = 7001
    protocol = "TCP"
    self = true
  }

  ingress {
    from_port = 10250
    to_port = 10250
    protocol = "TCP"
    self = true
  }

  ingress {
    from_port = 53
    to_port = 53
    protocol = "TCP"
    self = true
  }

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "UDP"
    self = true
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "ssh_key" {
  key_name = "ssh_key"
  public_key = "${var.ssh_public_key}"
}

resource "template_file" "cloud_init" {
  template = "${file("coreos/cloud_init.yaml.tpl")}"
  vars {
    discovery_url = "${var.discovery_url}"
  }
}

resource "aws_elb" "kube_master" {
  name = "kube-master"

  subnets = ["${aws_instance.master.*.subnet_id}"]
  security_groups = ["${aws_security_group.kube_cluster.id}"]
  instances = ["${aws_instance.master.*.id}"]

  listener {
    instance_port = 443
    instance_protocol = "tcp"
    lb_port = 443
    lb_protocol = "tcp"
  }

  listener {
    instance_port = 80
    instance_protocol = "tcp"
    lb_port = 80
    lb_protocol = "tcp"
  }

  listener {
    instance_port = 8080
    instance_protocol = "tcp"
    lb_port = 8080
    lb_protocol = "tcp"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 5
    target = "SSL:443"
    interval = 10
  }

  # openssl
  provisioner "local-exec" {
    command = "sed 's|<MASTER_HOST>|${self.dns_name}|g' openssl/openssl.cnf.tpl > openssl/certs/openssl.cnf && cd openssl && source generate_certs.sh"
  }

  provisioner "local-exec" {
    command = "sed 's|<MASTER_HOST>|${self.dns_name}|g' local/setup_kubectl.sh.tpl > local/setup_kubectl.sh && cd local && source setup_kubectl.sh"
  }
}

# master nodes
resource "aws_instance" "master" {
  count = "${var.master_count}"

  ami = "${lookup(var.amis, var.region)}"
  instance_type = "${var.master_instance_type}"
  root_block_device = {
    volume_type = "gp2"
    volume_size = "${var.master_volume_size}"
  }
  security_groups = ["${aws_security_group.kube_cluster.name}"]
  iam_instance_profile = "${aws_iam_instance_profile.master_profile.name}"
  user_data = "${template_file.cloud_init.rendered}"
  key_name = "${aws_key_pair.ssh_key.key_name}"
}

resource "null_resource" "master" {
  count = "${var.master_count}"

  depends_on = ["aws_elb.kube_master"]

  triggers {
    etcd_endpoints = "${join(",", formatlist("http://%s:2379", aws_instance.master.*.private_ip))}"
    etcd_server = "${format("http://%s:2379", aws_instance.master.0.private_ip)}"
  }

  connection {
    host = "${element(aws_instance.master.*.public_ip, count.index)}"
    type = "ssh"
    user = "core"
    private_key = "${file(var.ssh_private_key_path)}"
  }

  provisioner "file" {
    source = "openssl/certs"
    destination = "/tmp"
  }

  provisioner "file" {
    source = "shared/"
    destination = "/tmp"
  }

  provisioner "file" {
    source = "master/"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/kubernetes/ssl",
      "sudo mv /tmp/certs/ca.pem /etc/kubernetes/ssl/ca.pem",
      "sudo mv /tmp/certs/apiserver.pem /etc/kubernetes/ssl/apiserver.pem",
      "sudo mv /tmp/certs/apiserver-key.pem /etc/kubernetes/ssl/apiserver-key.pem",
      "rm -R /tmp/certs",
      "sudo chmod 600 /etc/kubernetes/ssl/*-key.pem",
      "sudo chown root:root /etc/kubernetes/ssl/*-key.pem",
      "sudo mkdir -p /opt/bin",
      "sudo curl -L -o /opt/bin/kubelet https://storage.googleapis.com/kubernetes-release/release/${var.kube_version}/bin/linux/amd64/kubelet",
      "sudo chmod +x /opt/bin/kubelet",
      "ETCD_ENDPOINTS=${self.triggers.etcd_endpoints}",
      "ETCD_SERVER=${self.triggers.etcd_server}",
      "ADVERTISE_IP=${element(aws_instance.master.*.private_ip, count.index)}",
      "ADVERTISE_DNS=${element(aws_instance.master.*.private_dns, count.index)}",
      "sed -i \"s|<ADVERTISE_IP>|$ADVERTISE_IP|g\" /tmp/options.env",
      "sed -i \"s|<ETCD_ENDPOINTS>|$ETCD_ENDPOINTS|g\" /tmp/options.env",
      "sudo mkdir -p /etc/flannel",
      "sudo mv /tmp/options.env /etc/flannel/options.env",
      "sudo mkdir -p /etc/systemd/system/flanneld.service.d",
      "sudo mv /tmp/40-ExecStartPre-symlink.conf /etc/systemd/system/flanneld.service.d/40-ExecStartPre-symlink.conf",
      "sudo mkdir -p /etc/systemd/system/docker.service.d",
      "sudo mv /tmp/40-flannel.conf /etc/systemd/system/docker.service.d/40-flannel.conf",
      "sed -i \"s|<ADVERTISE_DNS>|$ADVERTISE_DNS|g\" /tmp/kubelet.service",
      "sudo mv /tmp/kubelet.service /etc/systemd/system/kubelet.service",
      "sed -i 's|<KUBE_VERSION>|${var.kube_version}|g' /tmp/kube-apiserver.yaml",
      "sed -i \"s|<ETCD_ENDPOINTS>|$ETCD_ENDPOINTS|g\" /tmp/kube-apiserver.yaml",
      "sed -i \"s|<ADVERTISE_IP>|$ADVERTISE_IP|g\" /tmp/kube-apiserver.yaml",
      "sudo mkdir -p /etc/kubernetes/manifests",
      "sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml",
      "sed -i 's|<KUBE_VERSION>|${var.kube_version}|g' /tmp/kube-proxy.yaml",
      "sudo mv /tmp/kube-proxy.yaml /etc/kubernetes/manifests/kube-proxy.yaml",
      "sed -i \"s|<ETCD_ENDPOINTS>|$ETCD_ENDPOINTS|g\" /tmp/kube-podmaster.yaml",
      "sed -i \"s|<ADVERTISE_IP>|$ADVERTISE_IP|g\" /tmp/kube-podmaster.yaml",
      "sudo mv /tmp/kube-podmaster.yaml /etc/kubernetes/manifests/kube-podmaster.yaml",
      "sudo mkdir -p /srv/kubernetes/manifests",
      "sed -i 's|<KUBE_VERSION>|${var.kube_version}|g' /tmp/kube-controller-manager.yaml",
      "sudo mv /tmp/kube-controller-manager.yaml /srv/kubernetes/manifests/kube-controller-manager.yaml",
      "sed -i 's|<KUBE_VERSION>|${var.kube_version}|g' /tmp/kube-scheduler.yaml",
      "sudo mv /tmp/kube-scheduler.yaml /srv/kubernetes/manifests/kube-scheduler.yaml",
      "sudo systemctl daemon-reload",
      "curl -X PUT -d 'value={\"Network\":\"10.2.0.0/16\",\"Backend\":{\"Type\":\"vxlan\"}}' \"$ETCD_SERVER/v2/keys/coreos.com/network/config\"",
      "sudo systemctl start kubelet",
      "sudo systemctl enable kubelet",
      "until $(curl -o /dev/null -sf http://127.0.0.1:8080/version); do printf '.'; sleep 5; done",
      "curl -X POST -d '{\"apiVersion\":\"v1\",\"kind\":\"Namespace\",\"metadata\":{\"name\":\"kube-system\"}}' \"http://127.0.0.1:8080/api/v1/namespaces\""
    ]
  }
}

# worker nodes
resource "aws_instance" "worker" {
  count = "${var.worker_count}"

  ami = "${lookup(var.amis, var.region)}"
  instance_type = "${var.worker_instance_type}"
  root_block_device = {
    volume_type = "gp2"
    volume_size = "${var.worker_volume_size}"
  }
  security_groups = ["${aws_security_group.kube_cluster.name}"]
  iam_instance_profile = "${aws_iam_instance_profile.worker_profile.name}"
  key_name = "${aws_key_pair.ssh_key.key_name}"
}

resource "null_resource" "worker" {
  count = "${var.worker_count}"

  depends_on = ["null_resource.master"]

  triggers {
    etcd_endpoints = "${join(",", formatlist("http://%s:2379", aws_instance.master.*.private_ip))}"
  }

  connection {
    host = "${element(aws_instance.worker.*.public_ip, count.index)}"
    type = "ssh"
    user = "core"
    private_key = "${file(var.ssh_private_key_path)}"
  }

  provisioner "file" {
    source = "openssl/certs"
    destination = "/tmp"
  }

  provisioner "file" {
    source = "shared/"
    destination = "/tmp"
  }

  provisioner "file" {
    source = "worker/"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/kubernetes/ssl",
      "sudo mv /tmp/certs/ca.pem /etc/kubernetes/ssl/ca.pem",
      "sudo mv /tmp/certs/worker.pem /etc/kubernetes/ssl/worker.pem",
      "sudo mv /tmp/certs/worker-key.pem /etc/kubernetes/ssl/worker-key.pem",
      "rm -R /tmp/certs",
      "sudo chmod 600 /etc/kubernetes/ssl/*-key.pem",
      "sudo chown root:root /etc/kubernetes/ssl/*-key.pem",
      "sudo mkdir -p /opt/bin",
      "sudo curl -L -o /opt/bin/kubelet https://storage.googleapis.com/kubernetes-release/release/${var.kube_version}/bin/linux/amd64/kubelet",
      "sudo chmod +x /opt/bin/kubelet",
      "MASTER_HOST=${aws_elb.kube_master.dns_name}",
      "ETCD_ENDPOINTS=${self.triggers.etcd_endpoints}",
      "ADVERTISE_IP=${element(aws_instance.worker.*.private_ip, count.index)}",
      "ADVERTISE_DNS=${element(aws_instance.worker.*.private_dns, count.index)}",
      "sed -i \"s|<ADVERTISE_IP>|$ADVERTISE_IP|g\" /tmp/options.env",
      "sed -i \"s|<ETCD_ENDPOINTS>|$ETCD_ENDPOINTS|g\" /tmp/options.env",
      "sudo mkdir -p /etc/flannel",
      "sudo mv /tmp/options.env /etc/flannel/options.env",
      "sudo mkdir -p /etc/systemd/system/flanneld.service.d",
      "sudo mv /tmp/40-ExecStartPre-symlink.conf /etc/systemd/system/flanneld.service.d/40-ExecStartPre-symlink.conf",
      "sudo mkdir -p /etc/systemd/system/docker.service.d",
      "sudo mv /tmp/40-flannel.conf /etc/systemd/system/docker.service.d/40-flannel.conf",
      "sed -i \"s|<MASTER_HOST>|$MASTER_HOST|g\" /tmp/kubelet.service",
      "sed -i \"s|<ADVERTISE_DNS>|$ADVERTISE_DNS|g\" /tmp/kubelet.service",
      "sudo mv /tmp/kubelet.service /etc/systemd/system/kubelet.service",
      "sed -i 's|<KUBE_VERSION>|${var.kube_version}|g' /tmp/kube-proxy.yaml",
      "sed -i \"s|<MASTER_HOST>|$MASTER_HOST|g\" /tmp/kube-proxy.yaml",
      "sudo mkdir -p /etc/kubernetes/manifests",
      "sudo mv /tmp/kube-proxy.yaml /etc/kubernetes/manifests/kube-proxy.yaml",
      "sudo mv /tmp/worker-kubeconfig.yaml /etc/kubernetes/worker-kubeconfig.yaml",
      "sudo systemctl daemon-reload",
      "sudo systemctl start kubelet",
      "sudo systemctl enable kubelet"
    ]
  }
}

resource "null_resource" "addons" {
  depends_on = ["null_resource.worker"]

  provisioner "local-exec" {
    command = "until $(kubectl create -f addons/ > /dev/null); do sleep 10; done"
  }
}
