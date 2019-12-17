# terraform-k8s-backup

This repository contains the Terraform code used to create a budget K8S Highly Available environment in AWS for experimenting.

Please note that eu-west-1 region is only supported but I will be looking to update this soon. The region can easily be changed in the code if necesssary.

The following resources are created:
* VPC with associated subnets etc
* 4 x Spot requests for t2.medium Centos 7 instances (3 x master, 1 x worker)
* A network load balancer for connecting to the master nodes

Costs at the time of writing:

4 x t2.medium @ $0.015 per Hour = $0.06
1 x NLB @ $0.0252 per hour = $0.0252

Total = $0.11 / hour (rounded up) + plus any transfer costs etc (expect to be close to $0.00 for experimenting).

It is linked in from the following blogpost https://devopsgoat.home.blog/2019/12/16/building-an-ha-kubernetes-cluster-in-aws-using-spot-instances/

## Variables

| Name | Description |
|------|-------------|
| k8s_version | The version string for the K8S version<br>This has only been tested with versions 1.14.X so far |
| stackname | The unique name used to identify the stack<br>Instances etc. will be tagged appropriately |
| key_name | The name of the shh key to associate with the instances.<br>This key should pre-exist in the account |

## Usage

To launch the stack using Terraform
```
terraform init
terraform plan
terraform apply
```

### Creating the cluster

The following procedures will build a 3 master cluster with a single worker node. It will also install Calico for the pod networking implementation. 

1. Load the SSH key into the SSH agent

        eval $(ssh-agent) && ssh-add [path-to-key]
1. SSH to the first master node following the advice from the Terrafom output:

        ssh -A -p 2220 centos@[nat public address]
1. Initialize the cluster

        sudo -E /usr/local/bin/k8s-init-master.sh
1. Join the other control plane nodes to the master

        sudo -E sh -c ". ~/.bash_profile; /usr/local/bin/k8s-join-controlplane.sh"
1. Join the worker nodes to the cluster

        sudo -E sh -c ". ~/.bash_profile; /usr/local/bin/k8s-join-workers.sh"

1. Check that the nodes are "Ready"

        sudo -E sh -c ". ~/.bash_profile; kubectl get no"


## Terraform Versions
This example supports Terraform v0.12

