#### AWS Fleet ####
#Connect to AWS
provider "aws" {
  region = "us-west-2"
}

#Build out my VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.37.0"

  name = "dev"

  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  vpc_tags = {
    Name = "dev-environment"
  }
}

#Deploy the Fleet
module "aws_webserver_cluster" {
  source = "github.com/gmaentz/terraform/modules/services/webserver-cluster"
  cluster_name = "webserver-dev"
  ami = "ami-a9d09ed1"
  key_name = "MyOregonSSH"
  instance_type = "t2.micro"
  min_size = 10
  max_size = 20
  vpc_id = "${module.vpc.vpc_id}"
  subnet_ids = ["${module.vpc.public_subnets}"]
}
module "cloud_watch" {
  source = "github.com/gmaentz/terraform/modules/services/cloud-watch"
  sms_number = "${var.sms_number}"
  autoscaling_group = "${module.aws_webserver_cluster.asg_name}"
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