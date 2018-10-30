provider "aws" {
  region = "us-east-2"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "prod"

  cidr = "10.5.0.0/16"

  azs             = ["us-east-2a", "us-east-2b", "us-east-2c"]
  private_subnets = ["10.5.1.0/24", "10.5.2.0/24", "10.5.3.0/24"]
  public_subnets  = ["10.5.101.0/24", "10.5.102.0/24", "10.5.103.0/24"]
  database_subnets = ["10.5.201.0/24", "10.5.202.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Owner       = "user"
    Environment = "prod"
  }

  vpc_tags = {
    Name = "prod-environment"
  }
}

module "webserver_cluster" {
	source = "github.com/gmaentz/terraform/modules/services/webserver-cluster"
  cluster_name		= "webserver-prod"
  ami             = "ami-8c122be9"
  key_name        = "AWSOhio"
	instance_type		= "t2.micro"
	min_size			= 8
	max_size			= 10

  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = ["${module.vpc.public_subnets}"]
}


#### Azure Fleet ####
# Connect to Azure
# Authenticate with Azure and Create a Resource Group
# Set through CLI or env variables - 
# How To: https://www.terraform.io/docs/providers/azurerm/authenticating_via_service_principal.html

# Configure the Azure Provider
provider "azurerm" {}

# Create a resource group
resource "azurerm_resource_group" "network" {
  name     = "devtest"
  location = "eastus2"
}

# Build Virtual Network
module "network" {
    source              = "Azure/network/azurerm"
    resource_group_name = "${azurerm_resource_group.network.name}"
    location            = "${azurerm_resource_group.network.location}"
    address_space       = "10.0.0.0/16"
    subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    subnet_names        = ["subnet1", "subnet2", "subnet3"]

    tags                = {
                            owner = "user"
                            environment = "dev-environment"
                          }
}

# Deploy the Fleet
module "azure_webserver_cluster" {
    source = "github.com/gmaentz/terraform_azure/modules/vmss"
    location =  "${azurerm_resource_group.network.location}"
    resource_group_name = "${azurerm_resource_group.network.name}"
    virtual_network_name = "${module.network.vnet_name}"
    subnet_id = "${module.network.vnet_subnets[0]}"
    application_port = 80
    admin_user = "azureuser"
    admin_password = "AzureAdminP@ssword1"
    cluster_name = "webserver-dev"
    cluster_size = "2"
    instance_type = "Standard_D1_v2"
    cloud_config_file = "web.conf"
    tags                = {
                            owner = "user"
                            environment = "dev-environment"
                          }
 }
