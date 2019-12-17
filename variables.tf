variable "ami_nat" {
    default = "ami-024107e3e3217a248"
}

variable "stackname" {
    default = "k8s-ha-recovery"
}

variable "k8s_version" {
    default = "1.15.7"
}

variable "key_name" {
    default = "devops-key"
}

variable "my_public_ip" {
    default = "151.231.159.184/32"
}