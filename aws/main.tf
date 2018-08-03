# Configure the Amazon AWS Provider
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

variable "aws_access_key" {
  default     = "xxx"
  description = "Amazon AWS Access Key"
}

variable "aws_secret_key" {
  default     = "xxx"
  description = "Amazon AWS Secret Key"
}

variable "prefix" {
  default     = "yourname"
  description = "Cluster Prefix - All resources created by Terraform have this prefix prepended to them"
}

variable "rancher_version" {
  default     = "v2.0.6"
  description = "Rancher Server Version"
}

variable "count_agent_all_nodes" {
  default     = "3"
  description = "Number of Agent All Designation Nodes"
}

variable "count_agent_etcd_nodes" {
  default     = "0"
  description = "Number of ETCD Nodes"
}

variable "count_agent_controlplane_nodes" {
  default     = "0"
  description = "Number of K8s Control Plane Nodes"
}

variable "count_agent_worker_nodes" {
  default     = "0"
  description = "Number of Worker Nodes"
}

variable "admin_password" {
  default     = "admin"
  description = "Password to set for the admin account in Rancher"
}

variable "cluster_name" {
  default     = "quickstart"
  description = "Kubernetes Cluster Name"
}

variable "region" {
  default     = "us-west-2"
  description = "Amazon AWS Region for deployment"
}

variable "type" {
  default     = "t2.medium"
  description = "Amazon AWS Instance Type"
}

variable "docker_version_server" {
  default     = "17.03"
  description = "Docker Version to run on Rancher Server"
}

variable "docker_version_agent" {
  default     = "17.03"
  description = "Docker Version to run on Kubernetes Nodes"
}

variable "ssh_key_name" {
  default     = ""
  description = "Amazon AWS Key Pair Name"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "rancher_sg_allowall" {
  name = "${var.prefix}-allowall"

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "rancherserver" {
  count           = "1"
  ami             = "${data.aws_ami.ubuntu.id}"
  instance_type   = "${var.type}"
  key_name        = "${var.ssh_key_name}"
  security_groups = ["${aws_security_group.rancher_sg_allowall.name}"]
  user_data       = "${data.template_file.userdata_server.rendered}"

  tags {
    Name = "${var.prefix}-rancherserver"
  }
}

resource "aws_instance" "rancheragent-all" {
  count           = "${var.count_agent_all_nodes}"
  ami             = "${data.aws_ami.ubuntu.id}"
  instance_type   = "${var.type}"
  key_name        = "${var.ssh_key_name}"
  security_groups = ["${aws_security_group.rancher_sg_allowall.name}"]
  user_data       = "${data.template_file.userdata_agent.rendered}"

  tags {
    Name = "${var.prefix}-rancheragent-${count.index}-all"
  }
}

resource "aws_instance" "rancheragent-etcd" {
  count           = "${var.count_agent_etcd_nodes}"
  ami             = "${data.aws_ami.ubuntu.id}"
  instance_type   = "${var.type}"
  key_name        = "${var.ssh_key_name}"
  security_groups = ["${aws_security_group.rancher_sg_allowall.name}"]
  user_data       = "${data.template_file.userdata_agent.rendered}"

  tags {
    Name = "${var.prefix}-rancheragent-${count.index}-etcd"
  }
}

resource "aws_instance" "rancheragent-controlplane" {
  count           = "${var.count_agent_controlplane_nodes}"
  ami             = "${data.aws_ami.ubuntu.id}"
  instance_type   = "${var.type}"
  key_name        = "${var.ssh_key_name}"
  security_groups = ["${aws_security_group.rancher_sg_allowall.name}"]
  user_data       = "${data.template_file.userdata_agent.rendered}"

  tags {
    Name = "${var.prefix}-rancheragent-${count.index}-controlplane"
  }
}

resource "aws_instance" "rancheragent-worker" {
  count           = "${var.count_agent_worker_nodes}"
  ami             = "${data.aws_ami.ubuntu.id}"
  instance_type   = "${var.type}"
  key_name        = "${var.ssh_key_name}"
  security_groups = ["${aws_security_group.rancher_sg_allowall.name}"]
  user_data       = "${data.template_file.userdata_agent.rendered}"

  tags {
    Name = "${var.prefix}-rancheragent-${count.index}-worker"
  }
}

data "template_file" "userdata_server" {
  template = "${file("files/userdata_server")}"

  vars {
    admin_password        = "${var.admin_password}"
    cluster_name          = "${var.cluster_name}"
    docker_version_server = "${var.docker_version_server}"
    rancher_version       = "${var.rancher_version}"
  }
}


data "template_file" "userdata_agent" {
  template = "${file("files/userdata_agent")}"

  vars {
    admin_password       = "${var.admin_password}"
    cluster_name         = "${var.cluster_name}"
    docker_version_agent = "${var.docker_version_agent}"
    rancher_version      = "${var.rancher_version}"
    server_address       = "${aws_instance.rancherserver.public_ip}"
  }
}

output "rancher-url" {
  value = ["https://${aws_instance.rancherserver.public_ip}"]
}