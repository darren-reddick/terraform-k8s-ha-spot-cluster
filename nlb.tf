resource "aws_alb" "control_plane" {
  name               = "${var.stackname}-api-server"
  internal           = true
  load_balancer_type = "network"
  enable_cross_zone_load_balancing = true
  subnets            = module.vpc.private_subnets

  tags = {
    Name = "api-server-${var.stackname}"
  }
}

resource "aws_alb_listener" "control_plane" {
    load_balancer_arn = aws_alb.control_plane.arn
    port              = "6443"
    protocol          = "TCP"
    default_action {
        type = "forward"
        target_group_arn = aws_alb_target_group.apiserver.arn
    }
}

resource "aws_alb_target_group" "apiserver" {
    name                = "apiserver-tg-${var.stackname}"
    port                = "6443"
    protocol            = "TCP"
    target_type = "ip"
    vpc_id              = module.vpc.vpc_id
    deregistration_delay = "30"

    health_check {
        healthy_threshold   = "3"
        unhealthy_threshold = "3"
        interval            = "30"
        //matcher             = "200"
        path                = "/healthz"
        port                = "6443"
        protocol            = "HTTPS"
    }

    tags = {
      Name = "apiserver-tg-${var.stackname}"
    }
}

resource "aws_lb_target_group_attachment" "kubemaster" {
  count = length(aws_spot_instance_request.kubemaster)
  target_group_arn = aws_alb_target_group.apiserver.arn
  target_id        = "${data.aws_instance.kubemaster.*.private_ip[count.index]}"
}

data "aws_instance" "kubemaster" {
  count = length(aws_spot_instance_request.kubemaster)
  instance_id = aws_spot_instance_request.kubemaster.*.spot_instance_id[count.index]
}

data "aws_instance" "kubeworker" {
  count = length(aws_spot_instance_request.kubeworker)
  instance_id = aws_spot_instance_request.kubeworker.*.spot_instance_id[count.index]
} 