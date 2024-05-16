resource "aws_launch_template" "eks-node-group-lt" {
  name = "eks-ng-${var.custom_string}-${var.environment}"
  
  vpc_security_group_ids = [
    aws_security_group.eks_ssh.id,
    module.eks.cluster_primary_security_group_id
  ]
  monitoring {
    enabled = true
  }
  user_data = base64encode(templatefile("${path.module}/common/templates/userdata.sh.tpl", {}))
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Name = "eks-ng-${var.custom_string}-${var.environment}"
      },
      var.common_tags
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      {
        Name = "eks-ng-${var.custom_string}-${var.environment}"
      },
      var.common_tags
    )
  }

  tag_specifications {
    resource_type = "spot-instances-request"
    tags = merge(
      {
        Name = "eks-ng-${var.custom_string}-${var.environment}"
      },
      var.common_tags
    )
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    "Name" = "eks-ng-${var.custom_string}-${var.environment}"
  }
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source                          = "terraform-aws-modules/eks/aws"
  cluster_name                    = "${var.cluster_name}-${var.environment}"
  cluster_version                 = "1.28"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  vpc_id                          = data.aws_vpc.vpc.id
  subnet_ids                      = data.aws_subnets.subnets.ids



  tags = {
    "Name" = "${var.cluster_name}-${var.environment}"
  }

  eks_managed_node_group_defaults = {
    ami_type                   = "AL2_x86_64"
    instance_types             = ["t3a.medium","t3a.medium"]
    iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {
      devops_stage_node = {
        instance_types = ["t3a.medium","t3a.medium"]
        capacity_type  = "ON_DEMAND"
        min_size     = var.min_size
        max_size     = var.max_size
        desired_size = var.desired_size 
        key_name = data.aws_key_pair.ssh_key_pair.key_name    
        labels = {
          node = "worker"
        }
        update_config = {
          max_unavailable_percentage = 50 # or set `max_unavailable`
        }
        tags = var.common_tags

        block_device_mappings = {
          xvda = {
            device_name = "/dev/xvda"
            ebs = {
              volume_size           = "50"  
              volume_type           = "gp3"
              # iops                  = 3000
              # throughput            = 125
              # encrypted             = true
              delete_on_termination = true
            }
          }
        }
    }
  }
}

resource "aws_security_group" "eks_ssh" {
  description = "EKS SG for ssh internally"
  name        = "${var.cluster_name}-${var.environment}-eks-ng-sg"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }

  ingress {
    description = "All traffic between EKS nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "${var.cluster_name}-${var.environment}-eks-ng-sg"
  }
}
