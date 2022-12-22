resource "aws_ecs_cluster" "this" {
  #for_each          = var.ecs_clusters
  name               = var.name
}
