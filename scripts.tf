locals {
  k8s-init-master-sh =<<MASTERINIHA
#!/bin/bash

# create master node locally including aws provider
kubeadm init --experimental-upload-certs --config <(cat << EOF
---
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: v${var.k8s_version}
controlPlaneEndpoint: "${aws_alb.control_plane.dns_name}:6443"
apiServer:
  extraArgs:
    cloud-provider: aws
    feature-gates: "ExpandPersistentVolumes=true"
controllerManager:
  extraArgs:
    cloud-provider: aws
    configure-cloud-routes: "false"
networking:
  podSubnet: 192.168.0.0/16
---
apiVersion: kubeadm.k8s.io/v1beta1
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: aws
EOF
)

mkdir -p ~/.kube
cp -p /etc/kubernetes/admin.conf ~/.kube/config

# set up the admin config in the bash profile and current environment
export KUBECONFIG=/etc/kubernetes/admin.conf
cat << 'EOF' >> /root/.bash_profile
export KUBECONFIG=/etc/kubernetes/admin.conf
EOF

. /root/.bash_profile

kubectl apply -f https://docs.projectcalico.org/v3.9/manifests/calico.yaml
# now pulling the calico config from S3 so we have control and on v3.7

# install aws storage class
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/storage-class/aws/default.yaml

# check node status for the cluster
kubectl get nodes

MASTERINIHA

  k8s-join-controlplane-sh =<<JOINCONTROLPLANE
#!/bin/bash

certificatekey=$(kubeadm init phase upload-certs --experimental-upload-certs | tail -1)

# Get a list of control plane members that are not me!
masters=$(aws ec2 describe-instances --region eu-west-1 --filters "Name=tag:Kuberole,Values=master" "Name=instance-state-name,Values=running" "Name=tag:Stackname,Values=${var.stackname}" \
--query 'Reservations[].Instances[?PrivateDnsName!=`'$(hostname -f)'`].[PrivateDnsName]' \
--output text)

for master in $masters
do
  ssh centos@$master << SCRIPT
sudo [ -f /etc/kubernetes/kubelet.conf ] && { echo "This worker looks to be a member of a cluster already"; exit; } || sudo $(kubeadm token create --print-join-command) --experimental-control-plane --certificate-key $certificatekey
sudo mkdir -p ~/.kube
sudo cp -p /etc/kubernetes/admin.conf ~/.kube/config
SCRIPT
done

JOINCONTROLPLANE

  k8s-join-workers-sh =<<JOINWORKERS
#!/bin/bash

# get a list of workers with taint to apply from Taint tag
workers=$(aws ec2 describe-instances --region eu-west-1 --filters "Name=tag:Kuberole,Values=worker" "Name=instance-state-name,Values=running" "Name=tag:Stackname,Values=${var.stackname}" \
--query 'Reservations[].Instances[].[PrivateDnsName]' \
--output text)

# get the join command
join=$(kubeadm token create --print-join-command)

# parse out values from the join command
token=$(echo $join | sed 's/.\+--token\ \([^\ ]\+\).\+/\1/')
apiserver=$(echo $join | awk '{print $3}')
discoverytokenca=$(echo $join | awk '{print $NF}')

# join the workers using a config file created locally and scopied out
# including any taints to register

cat << EOF > cluster-join.yml
apiVersion: kubeadm.k8s.io/v1beta1
kind: JoinConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: aws
    enforce-node-allocatable: pods
discovery:
  bootstrapToken:
    apiServerEndpoint: $apiserver
    token: $${token}
    caCertHashes:
    - $${discoverytokenca}
EOF

for worker in $workers
do
scp -o StrictHostKeyChecking=no cluster-join.yml centos@$${worker}:~
ssh -o StrictHostKeyChecking=no centos@$${worker} << SCRIPT
sudo mv cluster-join.yml /root/
sudo [ -f /etc/kubernetes/kubelet.conf ] && echo "This worker looks to be a member of a cluster already" || sudo kubeadm join --config /root/cluster-join.yml
SCRIPT
done

JOINWORKERS

}

resource "aws_s3_bucket_object" "k8s-init-master" {
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/k8s-init-master.sh"
  content =<<EOF
${local.k8s-init-master-sh}
EOF
}

resource "aws_s3_bucket_object" "k8s-join-controlplane" {
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/k8s-join-controlplane.sh"
  content =<<EOF
${local.k8s-join-controlplane-sh}
EOF
}

resource "aws_s3_bucket_object" "k8s-join-workers" {
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/k8s-join-workers.sh"
  content =<<EOF
${local.k8s-join-workers-sh}
EOF
}