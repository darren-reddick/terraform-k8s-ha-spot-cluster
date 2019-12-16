output "Accessing_nodes" {
    value = <<EOF

SSH TO NAT
==========
ssh -A ec2-user@${aws_instance.nat.public_ip}

CONNECTING TO NODES VIA NAT
============================
ssh -A -p 2220 centos@${aws_instance.nat.public_ip} # master0
ssh -A -p 2221 centos@${aws_instance.nat.public_ip} # master1
ssh -A -p 2222 centos@${aws_instance.nat.public_ip} # master2

ssh -A -p 2223 centos@${aws_instance.nat.public_ip} # worker0

EOF
}