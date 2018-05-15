## Terraform Nginx Deployment

** Requirement

+ A ~/.terraformrc file on user HOME, with the path to plugin directory

+ AWS Plugin module for terraform 

+ AWS access, secret key & SSH keys which must be setup in 'terraform.tfvars' file

+ Preferable Terraform version v0.11.7

### How to execute

First understand plan of execution by running following command

+ terraform plan --var-file="terraform.tfvars" --out plan_out

The command reads any file with extension '.tf' as for applying new or set desired state change to your infra. The plan_out file is the binary file which terraform uses to apply the infrastructure or any changes.

Apply the terraform plan on your setup by running

+ terraform apply "plan_out"

This would trigger the infrastructure deployment along with a lock file on the run path to lock the config changes that you are applying. A state file is also created after successful run to record the current state before further modification to the infrastructure

### How to Update the infrastructure

To update the state of infra, just modify your original '.tf' file & repeat the step from the start without the '--out' option

+ terraform plan --var-file="terraform.tfvars"

+ + terraform apply --var-file="terraform.tfvars"

This would refresh the state & generate back-up file of the state file that was created from previous execution as an insurance (roll-back) before applying the modification. It will also create lock file.

### Reference

+ https://www.terraform.io/docs/providers/aws/

+ https://www.terraform.io/docs/state/
