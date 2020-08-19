
# atlas regions use the underscore, opposed to hyphen -- not my idea :)
variable "atlas-region" {}

# Atlas API requires very specific enumeration (4/16/2020)
# reference: https://docs.atlas.mongodb.com/reference/api/vpc-create-container
#
# CA_CENTRAL_1
# US_EAST_1
# US_EAST_2
# US_WEST_1
# US_WEST_2
# SA_EAST_1


variable "region" {} 
variable "az1" {} 
variable "az2" {}

variable "mongo-centos-ami" {}

variable "mongodb_atlas_whitelistip" {}

variable "atlas-aws-cidr" {}
variable "amazon-account-number" {}
variable "atlas-public-key" {}
variable "atlas-private-key" {}

variable "atlas-organization-id" {}
variable "atlas-project-id" {}

variable "atlas-cloud-provider" {
  default = "AWS"
}

variable "atlas-reg" {}

variable "scenario" {} 
variable "public_key" {}
