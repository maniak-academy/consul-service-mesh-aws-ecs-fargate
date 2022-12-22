# consul-service-mesh-aws-ecs-fargate
The following is a demo to run Consul Service Mesh in AWS ECS-Fargate 

Service Mesh
Using Consul on AWS ECS enables you to add your ECS tasks to the service mesh and take advantage of features such as zero-trust-security, intentions, observability, traffic policy, and more. You can also connect service meshes so that services deployed across your infrastructure environments can communicate.

## Prerequisites
To complete this tutorial you will need the following.

* Basic command line access
* Terraform v1.0.0+ installed
* Git installed
* AWS account and associated credentials that allow you to create resources.

## How to Deploy

```
git clone https://github.com/maniak-academy/consul-service-mesh-aws-ecs-fargate.git
```

## Create and configure credential resources

Create a Terraform configuration file for your secrets
Terraform will utilize your unique credentials to build a complete Elastic Cloud Compute (EC2) Consul cluster and example application in Elastic Container Service (ECS).

Create a file named terraform.tfvars in your working directory and copy the following configuration into the file.

```
lb_ingress_ip = "YOUR_PUBLIC_IP"
region        = "us-east-1"
name = "learn-hcp"
consul_version = "1.14.2"
```


## Deploy the Consul + ECS environment

With the Terraform manifest files and your custom credentials file, you are now ready to deploy your infrastructure.

Issue the terraform init command from your working directory to download the necessary providers and initialize the backend.

 terraform init
 terraform plan
 terraform apply


## Outputs

* Consul Server UI
* HashiCups app 
* ACL Token to login


# Apply intentions
When you terraform apply, the Applicaiton will not work. You will need to add Rules to allow the services to talk to each other.

For example, the below are terraform examples. 


```
locals {
  public_api_name  = "public-api"
  frontend_name    = "frontend"
  product_api_name = "product-api"
  postgres_name    = "postgres"
  payments_name    = "payments"
}

resource "consul_config_entry" "product_api_intentions" {
  name = local.product_api_name
  kind = "service-intentions"

  config_json = jsonencode({
    Sources = [
      {
        Action     = "allow"
        Name       = local.public_api_name
        Precedence = 9
        Type       = "consul"
        Namespace  = "default"
      }
    ]
  })
}

resource "consul_config_entry" "public_api_intentions" {
  name = local.public_api_name
  kind = "service-intentions"

  config_json = jsonencode({
    Sources = [
      {
        Action     = "allow"
        Name       = local.frontend_name
        Precedence = 9
        Type       = "consul"
        Namespace  = "default"
      }
    ]
  })
}


resource "consul_config_entry" "deny_all" {
  name = "*"
  kind = "service-intentions"

  config_json = jsonencode({
    Sources = [
      {
        Action     = "deny"
        Name       = "*"
        Precedence = 9
        Type       = "consul"
        Namespace  = "default"
      }
    ]
  })
}

resource "consul_config_entry" "payments_intentions" {
  name = local.payments_name
  kind = "service-intentions"

  config_json = jsonencode({
    Sources = [
      {
        Action     = "allow"
        Name       = local.public_api_name
        Precedence = 9
        Type       = "consul"
        Namespace  = "default"
      }
    ]
  })
}


resource "consul_config_entry" "postgres_intentions" {
  name = local.postgres_name
  kind = "service-intentions"

  config_json = jsonencode({
    Sources = [
      {
        Action     = "allow"
        Name       = local.product_api_name
        Precedence = 9
        Type       = "consul"
        Namespace  = "default"
      }
    ]
  })
}
```

