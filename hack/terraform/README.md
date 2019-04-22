# Create your dev seesaw cluster

Install terraform on your desktop.

Update `terraform.tfvars` to fill in your configurations.

Run the following command to check the operations

```console
terraform init && terraform plan
```

Once done, run

```console
terraform apply
```

## TODOs
- It deploys github.com/anfernee/seesaw, not the current folder.
- It doesn't include config server. the backend is hard coded.
- It doesn't have init script. so it won't be started automatically.

