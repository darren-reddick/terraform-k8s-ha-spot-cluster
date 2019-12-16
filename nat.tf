resource "aws_instance" "nat" {
  ami           = var.ami_nat
  instance_type = "t2.micro"
  subnet_id = module.vpc.public_subnets.0
  source_dest_check = false
  root_block_device {
    delete_on_termination = true
    volume_type           = "gp2"
  }
  key_name = "${var.key_name}"
  vpc_security_group_ids = [aws_security_group.nat.id]
  tags = {
    Name = join("",[var.stackname,"-nat"])
  }
  user_data =<<EOF
#!/bin/bash

# ssh access to masters
iptables -t nat -A PREROUTING -p tcp --dport 2220 -j DNAT --to-destination ${data.aws_instance.kubemaster.*.private_ip[0]}:22
iptables -t nat -A PREROUTING -p tcp --dport 2221 -j DNAT --to-destination ${data.aws_instance.kubemaster.*.private_ip[1]}:22
iptables -t nat -A PREROUTING -p tcp --dport 2222 -j DNAT --to-destination ${data.aws_instance.kubemaster.*.private_ip[2]}:22

# ssh access to workers
iptables -t nat -A PREROUTING -p tcp --dport 2223 -j DNAT --to-destination ${data.aws_instance.kubeworker.*.private_ip[0]}:22


EOF
}

resource "aws_security_group" "nat" {
  name        = join("",[var.stackname,"-sg-nat"])
  description = "Security Group for nat instance"
  vpc_id      = module.vpc.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks     = [module.vpc.vpc_cidr_block]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks     = [module.vpc.vpc_cidr_block]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks     = ["212.139.189.130/32","151.231.159.184/32"]
  }
  ingress {
    from_port   = 2220
    to_port     = 2225
    protocol    = "tcp"
    cidr_blocks     = ["212.139.189.130/32","151.231.159.184/32"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


resource "aws_route" "nat" {
  count = length(module.vpc.private_route_table_ids)
  route_table_id              = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  instance_id = aws_instance.nat.id
}