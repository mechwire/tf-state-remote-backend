# tf-state-remote-backend

This is based on the work in [github-oidc-role](https://github.com/mechwire/github-oidc-role).

This uses GitHub OIDC and Terraform to create a remote backend to hold a tf state. This tf state will be usable in GitHub actions.

To allow for that, a reusable GitHub Action role creates the repository role. The repository role meant to be permissioned to access what it creates. Due to the limitations of ABAC or Tag-based policies for s3 and DynamoDB, instead, permissions are specified with a mixture of specifics and wildcards.

The goals were learning and automating infra deployments.

## Structure

* `./infra/setup` holds a helper module to assign the exact permissions needed to access the remote tf state table and bucket.
* `./infra/repo-role` holds a helper module. This allows for the easy creation of new roles per repo that have access to the remote tf state.
* `./.github/workflows/tf.yml` holds a GitHub action that executes TF validation and application (on merge to main). It will always execute the `infra/setup` folder, and then the `./infra` root. It calls on
    * `./.github/actions/tf-setup` to setup the tf environment, backend, variable passing mechanism, etc.
    * `./.github/actions/tf-init-apply` to perform formatting, validation, planning, and application (again, on merge to main)


## Security Policies Needed in this Approach

1. Ensure no one else can open PRs unless they should see the contents of a tf `plan`
2. Ensure no one else can see the outcomes of the tf `plan`, which can leak credentials on error

## Learnings

* It is easy to get into a chicken and egg mentality about what to make in Terraform versus not. I'm not 100% on how I would have liked to do it and ended up doing a mixture of sequential work and manual work to get things going.
* Terraform is declarative, but not truly declarative. There's no "transaction" concept where the failure of one of the things prevents the execution of others
* If something already exists, you need to use `data` instead of `resource`. If something is created and then the tfstate is lost, then it will try to make the same object twice instead of understanding that you want to modify something that exists.
* ABAC is not a universal concept.
* Resource-based policies seem a bit more limiting in cases where you want to continually update access to the bucket or table.
* GitHub Actions AWS doesn't easily support using different roles / providers within the same Terraform file. This led to the strange `infra/setup` and `infra` split.

# References

* [All Things DevOps - "How to Store Terraform State on S3"](https://medium.com/all-things-devops/how-to-store-terraform-state-on-s3-be9cd0070590) had great explanations on Terraform and why each step was needed
* [Spacelift - "How to Create and Manage an AWS S3 Bucket Using Terraform"](https://spacelift.io/blog/terraform-aws-s3-bucket) had Terraform examples
* [Terrateam - "Using Multiple AWS IAM Roles"](https://terrateam.io/blog/using-multiple-aws-iam-roles)
* [AWS - "Actions, resources, and condition keys for Amazon DynamoDB"](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazondynamodb.html#amazondynamodb-policy-keys), which specifies that DynamoDB doesn't support using `aws:ResourceTags` for creating tables
* [AWS - "Actions, resources, and condition keys for Amazon S3"](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazons3.html#amazons3-policy-keys), which specifies that DynamoDB doesn't s3 using `aws:ResourceTags` for creating buckets
* [Spacelift - "Terraform with GitHub Actions : How to Manage & Scale"](https://spacelift.io/blog/github-actions-terraform)

