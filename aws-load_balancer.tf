locals {
  load_balancer_name         = var.name
  load_balancer_target_group = "${var.name}-target-group"
}

resource "aws_lb" "example_client_app" {
  name               = local.load_balancer_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.example_client_app_alb.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "hashicups" {
  for_each             = { for service in var.target_group_settings.elb.services : service.name => service }
  name                 = each.value.name
  port                 = each.value.port
  protocol             = each.value.protocol
  target_type          = each.value.target_group_type
  vpc_id               = module.vpc.vpc_id
  deregistration_delay = 10
  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 30
    interval            = 60
    // Try function added due to public-api not listening on the default traffic ports but port 8080
    port                = try(each.value.health.port, "traffic-port")
  }
}

resource "aws_lb_listener" "hashicups" {
  for_each          = aws_lb_target_group.hashicups
  load_balancer_arn = aws_lb.example_client_app.arn
  port              = each.value.port
  protocol          = each.value.protocol
  default_action {
    type             = "forward"
    target_group_arn = each.value.arn
  }
}


## Consul

resource "aws_lb" "consul" {
  name               = "${var.name}-consul"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.consul.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "consul" {
  name                 = "${var.name}-consul"
  port                 = 8500
  protocol             = "HTTP"
  vpc_id               = module.vpc.vpc_id
  deregistration_delay = 10
  health_check {
    path                = "/v1/status/leader"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 30
    interval            = 60
  }
}

resource "aws_lb_listener" "consul" {
  load_balancer_arn = aws_lb.consul.arn
  port              = "8500"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.consul.arn
  }
}

resource "aws_lb_target_group_attachment" "consul" {
  target_group_arn = aws_lb_target_group.consul.arn
  target_id        = aws_instance.consul.id
}
