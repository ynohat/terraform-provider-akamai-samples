Collection of Akamai Terraform provider samples.

## Sample descriptions

### 00_simple_amd_netstorage

Shows how to provision an Adaptive Media Delivery configuration using rules defined
in a JSON template.

There is nothing special about this setup. It is just an introduction to using Terraform
with Akamai properties.

### 01_multi_env_with_consul_backend

Builds on the previous example, adding support for multiple environments:

* Snippets : the configuration is split in manageable chunks and assembled at `apply` time
* Remote Backend : uses Consul to store state
* Multiple Workspaces : one per env

How to use it:

* update `terraform.tfvars` to match your setup
* for each environment that you plan to have, create `stages/${ENVNAME}.tfvars`
* run `docker-compose up -d` to start a local consul server
* create your workspaces: `for stage in dev qa prod; terraform workspace new $stage; done`

Operating:

```bash
# switch to dev
terraform workspace select dev
# update without activating
terraform apply -var-file stages/dev.tfvars -var staging=false -var production=false
# update and activate on staging
terraform apply -var-file stages/dev.tfvars -var staging=true
# update and activate on staging & production
terraform apply -var-file stages/dev.tfvars -var staging=true -var production=true
```

> Currently activation always affects the latest version, this is not ideal; pending
> resolution of https://github.com/terraform-providers/terraform-provider-akamai/issues/88

> For simplicity, every configuration uses the same origin. It is trivial to change this
> by adding appropriate variables to each stage as needed.

### 02_golden_master_pattern

Uses an external data source to retrieve the rules from an existing property - the master.

The master is not managed by terraform; it is managed in property manager using the UI, and
can be edited by PS.

Terraform then handles deploying the rules to the environments it manages.

Operation is similar to the previous example.

## Thanks

This work owes a lot to @IanCassTwo (snippets!). Check out [more cool examples of his](https://github.com/IanCassTwo/terraform-provider-akamai-examples).