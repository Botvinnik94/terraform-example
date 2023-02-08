# Terraform template example

This repository provides an example of using Terraform to provision infrastructure in Azure. The example is meant to serve as a template for people who are new to Terraform or looking for a simple example to get started with.

## Prerequisites
To use this example, you need to have the following installed:
- [Terraform CLI](https://developer.hashicorp.com/terraform/downloads)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- An Azure account with a working subscription

## Usage
1. Clone the repository

```bash
git clone https://github.com/Botvinnik94/terraform-example.git
```

2. Authenticate to Azure CLI

```bash
az login
```

3. Navigate to the repository directory

```bash
cd terraform-example
```

4. Check and modify the configuration files if necessary:
    - `main.tf` contains the infrastructure definition.
    - `variables.tf` contains the variables used in the infrastructure definition.
    - `vars/<env>.tfvars` contains the actual variable value for each environment.

5. Ensure that you have created the following resources in Azure (you can change the naming by modifying the backend names in `main.tf`):
    - Resource Group with the name `botvinnik-tf-rg`
    - Storage Account within that Resource group with the name `botvinniktfstac`
    - Container within that Storage Account with the name `botvinnik-tf-cont`

6. Initialize Terraform
```bash
terraform init
```

7. Plan the Terraform execution with the variable file for the target environment
```bash
terraform plan -var-file=vars/<env>.tfvars
```

8. Apply the Terraform execution
```bash
terraform apply -var-file=vars/<env>.tfvars
```

## Clean up
To destroy the resources created by Terraform, run:
```bash
terraform destroy
```