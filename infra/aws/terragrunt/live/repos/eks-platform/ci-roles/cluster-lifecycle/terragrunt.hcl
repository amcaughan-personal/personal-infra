include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path           = find_in_parent_folders("common.hcl")
  merge_strategy = "deep"
}

terraform {
  source = "${get_repo_root()}/infra/aws/terragrunt//modules/github-ci-environment-role"
}

locals {
  cluster = "main"
  arn     = "arn:aws:%s:us-east-2:${get_aws_account_id()}:%s"
  roles   = "arn:aws:iam::${get_aws_account_id()}:role/eks-platform-${local.cluster}-%s"

  tagged_as_cluster = [{ test = "StringEquals", variable = "aws:ResourceTag/Cluster", values = [local.cluster] }]
}

# Brings eks-platform's main cluster up and down (its clusters/main stacks and
# scripts/cluster-down.sh), and nothing else: no IAM roles (those are in its shared/), and no
# EC2 resources not tagged as this cluster's.
inputs = {
  repo                = "eks-platform"
  oidc_subject_prefix = "repo:amcaughan-personal@271645414/eks-platform@1470781527"
  purpose             = "cluster-lifecycle"
  description         = "bring the main cluster up and down"

  # cluster-up.yml runs in the cluster-up environment (which needs approval); cluster-down.yml
  # runs on main, by hand or on its nightly schedule.
  trusted = [
    { environment = "cluster-up", workflow = "cluster-up.yml" },
    { ref = "refs/heads/main", workflow = "cluster-down.yml" },
  ]

  read_access          = true
  state_write_prefixes = ["live/clusters/"]

  statements = [
    {
      sid = "Cluster"
      actions = [
        "eks:CreateCluster", "eks:DeleteCluster", "eks:UpdateClusterConfig", "eks:UpdateClusterVersion",
        "eks:TagResource", "eks:UntagResource",
        "eks:CreateNodegroup", "eks:DeleteNodegroup", "eks:UpdateNodegroupConfig", "eks:UpdateNodegroupVersion",
        "eks:CreateAddon", "eks:DeleteAddon", "eks:UpdateAddon",
        "eks:CreateAccessEntry", "eks:DeleteAccessEntry", "eks:UpdateAccessEntry",
        "eks:AssociateAccessPolicy", "eks:DisassociateAccessPolicy",
        "eks:CreatePodIdentityAssociation", "eks:DeletePodIdentityAssociation", "eks:UpdatePodIdentityAssociation",
      ]
      resources = [
        format(local.arn, "eks", "cluster/${local.cluster}"),
        format(local.arn, "eks", "nodegroup/${local.cluster}/*/*"),
        format(local.arn, "eks", "addon/${local.cluster}/*/*"),
        format(local.arn, "eks", "access-entry/${local.cluster}/*"),
        format(local.arn, "eks", "podidentityassociation/${local.cluster}/*"),
      ]
    },
    # Security groups and launch templates only when created tagged as this cluster's.
    {
      sid        = "CreateTaggedNetworking"
      actions    = ["ec2:CreateSecurityGroup", "ec2:CreateLaunchTemplate"]
      resources  = ["*"]
      conditions = [{ test = "StringEquals", variable = "aws:RequestTag/Cluster", values = [local.cluster] }]
    },
    {
      sid        = "TagOnCreate"
      actions    = ["ec2:CreateTags"]
      resources  = ["*"]
      conditions = [{ test = "StringEquals", variable = "ec2:CreateAction", values = ["CreateSecurityGroup", "CreateLaunchTemplate"] }]
    },
    {
      sid = "ChangeTaggedNetworking"
      actions = [
        "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress", "ec2:DeleteSecurityGroup",
        "ec2:CreateLaunchTemplateVersion", "ec2:ModifyLaunchTemplate", "ec2:DeleteLaunchTemplate",
      ]
      resources  = ["*"]
      conditions = local.tagged_as_cluster
    },
    # Network interfaces the VPC CNI left behind (scripts/cluster-down.sh).
    {
      sid        = "DeleteLeakedInterfaces"
      actions    = ["ec2:DeleteNetworkInterface"]
      resources  = ["*"]
      conditions = [{ test = "StringEquals", variable = "aws:ResourceTag/cluster.k8s.amazonaws.com/name", values = [local.cluster] }]
    },
    # The cluster's existing roles (eks-platform's shared/iam), to EKS only.
    {
      sid        = "PassClusterRoles"
      actions    = ["iam:PassRole"]
      resources  = [format(local.roles, "cluster"), format(local.roles, "node")]
      conditions = [{ test = "StringEquals", variable = "iam:PassedToService", values = ["eks.amazonaws.com"] }]
    },
  ]

  role_arn_name = "LIFECYCLE_ROLE_ARN"
}
