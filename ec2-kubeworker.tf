resource "aws_spot_instance_request" "kubeworker" {
  count = "1"
  ami           = data.aws_ami.centos.id
  depends_on = [null_resource.delay-after-kubemaster-instance-profile]
  iam_instance_profile = "${aws_iam_instance_profile.kubemaster-instance-profile.id}"
  wait_for_fulfillment = true
  instance_type = "t2.medium"
  key_name = "${var.key_name}"
  subnet_id = module.vpc.private_subnets[count.index]
  source_dest_check = false
  vpc_security_group_ids = [aws_security_group.kubemaster.id]
  user_data = <<EOF
${local.worker_user_data}

echo "export PS1='[\u@WORKER${count.index} \W]\$ '" > /etc/profile.d/ps1.sh
EOF
  lifecycle {
    create_before_destroy = true
    ignore_changes = ["user_data"]
  }
  provisioner "local-exec" {
    command =<<EOF
aws ec2 create-tags --resources ${self.spot_instance_id} --tags Key=Name,Value=Kubeworker${count.index} --region ${data.aws_region.current.name}
aws ec2 create-tags --resources ${self.spot_instance_id} --tags Key=kubernetes.io/cluster/${var.stackname},Value=owned --region ${data.aws_region.current.name}
aws ec2 create-tags --resources ${self.spot_instance_id} --tags Key=Kuberole,Value=worker --region ${data.aws_region.current.name}
aws ec2 create-tags --resources ${self.spot_instance_id} --tags Key=Stackname,Value=${var.stackname} --region ${data.aws_region.current.name}
EOF
  }
}


locals {
  worker_user_data = <<USERDATA
#!/usr/bin/env bash

# turn off swap
swapoff -a
 
# comment out swap line from fstab
sed -i.bak 's/\(.*swap.*\)/#\1/' /etc/fstab
 
# set up kubernetes repo file
cat << 'EOF' > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
 
# set up k8s sysctl config
cat << 'EOF' > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
 
# setup docker repo, install
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum -y install docker
 
# change deafult logging to json file
sed -i.bak 's/--log-driver=.\+\ /--log-driver=json-file\ /g'  /etc/sysconfig/docker
 
# enable and start docker
systemctl enable docker
systemctl restart docker
 
# configure selinux to be permissive
setenforce 0 && sed -i.bak 's/^SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config
 
# update sysctl settings
sysctl --system
 
# install kubernetes components
yum -y install kubectl-${var.k8s_version} kubeadm-${var.k8s_version} kubelet-${var.k8s_version} kubernetes-cni
systemctl enable kubelet

cat << 'EOF' > /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --cloud-provider=aws"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
EOF
 
cat << 'EOF' > /usr/lib/systemd/system/kubelet.service.d/11-cgroups.conf
[Service]
CPUAccounting=true
MemoryAccounting=true
EOF
USERDATA
}


resource "aws_security_group" "kubeworker" {
  name        = join("",[var.stackname,"-sg-kubeworker"])
  description = "Security Group for kube worker instances"
  vpc_id      = module.vpc.vpc_id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks     = [join("",[aws_instance.nat.private_ip,"/32"])]
    security_groups = [aws_security_group.kubemaster.id]
    self = "true"
  }
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks     = concat(module.vpc.private_subnets_cidr_blocks,[join("",[aws_instance.nat.private_ip,"/32"])])
  }
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    self    = true
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
