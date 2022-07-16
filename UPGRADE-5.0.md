# Upgrade from v4.x to v5.x

Please consult the `examples` directory for reference example configurations. If you find a bug, please open an issue with supporting configuration to reproduce.

#### ⚠️ This guide is under active development. As tasks for v5.0 are implemented, the associated upgrade guidance/changes are documented here. See [here](https://github.com/aws-ia/terraform-aws-eks-blueprints/milestone/1) to track progress of v5.0 implementation.

## List of backwards incompatible changes

-

## Additional changes

### Added

-

### Modified

-

### Removed

-

### Variable and output changes

1. Removed variables:

    -

2. Renamed variables:

    -

3. Added variables:

    -

4. Removed outputs:

    -

5. Renamed outputs:

    -

6. Added outputs:

    -

## Upgrade Migrations

### Before - v4.x Example

```hcl
module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.4.0"

  cluster_name    = "upgrade"
  cluster_version = "1.20"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # Fargate
  fargate_profiles = {
    default = {
      fargate_profile_name = "default"
      fargate_profile_namespaces = [
        {
          namespace = "default"
        }
      ]

      additional_tags = {
        ExtraTag = "Fargate"
      }

      subnet_ids = module.vpc.private_subnets
    }
  }
}
```

### After - v5.x Example

```hcl
module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v5.0.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.22"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # Fargate
  fargate_profile_defaults = {
    # To maintain backwards compatibility w/ v4.x
    iam_role_use_name_prefix   = false
    iam_role_attach_cni_policy = false
  }

  fargate_profiles = {
    default = {
      name          = "default"
      iam_role_name = "${local.cluster_name}-default" # To maintain backwards compatibility w/ v4.x
      selectors = [
        {
          namespace = "default"
        }
      ]

      tags = {
        ExtraTag = "Fargate"
      }
    }
  }
}
```

### Diff of Before vs After

```diff
module "eks_blueprints" {
-  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.6.2"
+  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v5.0.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.22"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # Fargate
  fargate_profiles = {
    default = {
-      fargate_profile_name = "default"
+      name = "default"
-      fargate_profile_namespaces = [
+      selectors = [
        {
          namespace = "default"
        }
      ]
-      additional_tags = {
+      tags = {
        ExtraTag = "Fargate"
      }

-      subnet_ids = module.vpc.private_subnets
    }
  }
}
```

### State Move Commands

In conjunction with the changes above, users can elect to move their external capacity provider(s) under this module using the following move command. Command is shown using the values from the example shown above, please update to suit your configuration names:

#### Fargate Profiles

Please replace `<PROFILE_KEY>` with the name of the associated key for the Fargate profile definition that is being migrated across versions:
```sh
terraform state mv 'module.eks_blueprints.module.aws_eks_fargate_profiles["<PROFILE_KEY>"].aws_eks_fargate_profile.eks_fargate' 'module.eks_blueprints.module.aws_eks.module.fargate_profile["<PROFILE_KEY>"].aws_eks_fargate_profile.this[0]'
terraform state mv 'module.eks_blueprints.module.aws_eks_fargate_profiles["<PROFILE_KEY>"].aws_iam_role.fargate[0]' 'module.eks_blueprints.module.aws_eks.module.fargate_profile["<PROFILE_KEY>"].aws_iam_role.this[0]'
terraform state mv 'module.eks_blueprints.module.aws_eks_fargate_profiles["<PROFILE_KEY>"].aws_iam_role_policy_attachment.fargate_pod_execution_role_policy["arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"]' 'module.eks_blueprints.module.aws_eks.module.fargate_profile["<PROFILE_KEY>"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"]'
```

For the `examples/fargate-serverless` example, the move commands are:
```sh
terraform state mv 'module.eks_blueprints.module.aws_eks_fargate_profiles["default"].aws_eks_fargate_profile.eks_fargate' 'module.eks_blueprints.module.aws_eks.module.fargate_profile["default"].aws_eks_fargate_profile.this[0]'
terraform state mv 'module.eks_blueprints.module.aws_eks_fargate_profiles["default"].aws_iam_role.fargate[0]' 'module.eks_blueprints.module.aws_eks.module.fargate_profile["default"].aws_iam_role.this[0]'
terraform state mv 'module.eks_blueprints.module.aws_eks_fargate_profiles["default"].aws_iam_role_policy_attachment.fargate_pod_execution_role_policy["arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"]' 'module.eks_blueprints.module.aws_eks.module.fargate_profile["default"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"]'

terraform state mv 'module.eks_blueprints.module.aws_eks_fargate_profiles["kube_system"].aws_eks_fargate_profile.eks_fargate' 'module.eks_blueprints.module.aws_eks.module.fargate_profile["kube_system"].aws_eks_fargate_profile.this[0]'
terraform state mv 'module.eks_blueprints.module.aws_eks_fargate_profiles["kube_system"].aws_iam_role.fargate[0]' 'module.eks_blueprints.module.aws_eks.module.fargate_profile["kube_system"].aws_iam_role.this[0]'
terraform state mv 'module.eks_blueprints.module.aws_eks_fargate_profiles["kube_system"].aws_iam_role_policy_attachment.fargate_pod_execution_role_policy["arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"]' 'module.eks_blueprints.module.aws_eks.module.fargate_profile["kube_system"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"]'

terraform state mv 'module.eks_blueprints.module.aws_eks_fargate_profiles["alb_sample_app"].aws_eks_fargate_profile.eks_fargate' 'module.eks_blueprints.module.aws_eks.module.fargate_profile["alb_sample_app"].aws_eks_fargate_profile.this[0]'
terraform state mv 'module.eks_blueprints.module.aws_eks_fargate_profiles["alb_sample_app"].aws_iam_role.fargate[0]' 'module.eks_blueprints.module.aws_eks.module.fargate_profile["alb_sample_app"].aws_iam_role.this[0]'
terraform state mv 'module.eks_blueprints.module.aws_eks_fargate_profiles["alb_sample_app"].aws_iam_role_policy_attachment.fargate_pod_execution_role_policy["arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"]' 'module.eks_blueprints.module.aws_eks.module.fargate_profile["alb_sample_app"].aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"]'
```
