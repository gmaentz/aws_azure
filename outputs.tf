#### AWS Fleet #####
output "AWS Fleet" {
  value = "${module.aws_webserver_cluster.elb_dns_name}"
}

#### Azure Fleet #####
#DNS Name
 output "Azure Fleet" {
     value = "${module.azure_webserver_cluster.vmss_public_fqdn}"
 }