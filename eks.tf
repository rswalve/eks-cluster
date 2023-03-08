 terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.28.0"
    }
  }
}
/*
  backend "s3" {
    bucket = "mitre-name-iac"
    key    = "terraform/"
    region = "us-east-1"
  }
*/

provider "aws" {
  region = var.aws_region
}

data "aws_subnet_ids" "pub-subnet" {
  vpc_id = var.vpc_id

  filter {
    name   = "tag:Name"
    values = ["*Generic Private Subnet*"]
  }

}

output "subnet_ids" {
  value = data.aws_subnet_ids.pub-subnet.ids
}
/*
data "aws_subnet" "pub_subnet" {
  count = length(data.aws_subnet_ids.pub-subnet.ids)
  id    = tolist(data.aws_subnet_ids.pub-subnet.ids)[count.index]

}
*/


resource "aws_iam_role" "eks_cluster" {
  name = "experimental-MITRE-eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_eks_cluster" "aws_eks" {
  name     = "MITRETestground"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.22"

  vpc_config {
    subnet_ids = data.aws_subnet_ids.pub-subnet.ids
  }


  tags = {
    Name = "Cluster-MITRE-EKS"
  }
}

resource "aws_iam_role" "eks_nodes" {
  name = "MITRE-eks-node-group"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_eks_node_group" "node" {
  cluster_name    = aws_eks_cluster.aws_eks.name
  node_group_name = "eks-node"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = data.aws_subnet_ids.pub-subnet.ids

  #subnet_ids      = ["subnet-", "subnet-"]
  instance_types = ["t2.large", "t2.large", "t2.large"]
  disk_size      = "100"
  remote_access {
    ec2_ssh_key = "k8cluster-eks"
  }
  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }


  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}
