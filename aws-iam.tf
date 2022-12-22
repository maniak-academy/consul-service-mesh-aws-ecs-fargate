# Needed for the task definition to be able to write logs to Cloudwatch.
resource "aws_iam_role" "hashicups" {
  name = "hashicupsLogs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow"
        Principal = {
          #"AWS" = ["arn:aws:iam::561656980159:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"]
          "AWS" = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"]
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_policy" "hashicups" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["secretsmanager:GetSecretValue"]
        Effect = "Allow"
        Resource = [
          aws_secretsmanager_secret.gossip_key.arn,
          aws_secretsmanager_secret.bootstrap_token.arn,
          aws_secretsmanager_secret.ca_cert.arn,
          aws_lb.example_client_app.arn
        ]
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvent"
        ],
        Effect   = "Allow"
        Resource = ["*"]
      },
      {
        Action = ["elasticloadbalancing:*"]
        Effect = "Allow"
        Resource = [
          aws_lb.example_client_app.arn
        ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "hashicups" {
  policy_arn = aws_iam_policy.hashicups.arn
  role       = aws_iam_role.hashicups.name
}


resource "aws_iam_role" "consul" {
  name = "consul-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "consul" {
  name = "consul-instance-profile"
  role = aws_iam_role.consul.name
}

resource "aws_iam_role_policy" "describe_instances_policy" {
  name = "describe_instances_policy"
  role = aws_iam_role.consul.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:DescribeInstances"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}