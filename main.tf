###############
# VPC Section #
###############

# VPCs

resource "aws_vpc" "vpc-1" {
  cidr_block = "10.10.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.scenario}-vpc1-dev"
    scenario = "${var.scenario}"
    env = "dev"
  }
}
# Subnet

resource "aws_subnet" "vpc-1-sub-a" {
  vpc_id     = "${aws_vpc.vpc-1.id}"
  cidr_block = "10.10.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "${var.az1}"

  tags = {
    Name = "${aws_vpc.vpc-1.tags.Name}-sub-a"
  }
}


# Internet Gateway

resource "aws_internet_gateway" "vpc-1-igw" {
  vpc_id = "${aws_vpc.vpc-1.id}"

  tags = {
    Name = "${var.scenario}-vpc-1-igw"
    scenario = "${var.scenario}"
  }
}

# Main Route Tables Associations
## Forcing our Route Tables to be the main ones for our VPCs,
## otherwise AWS automatically will create a main Route Table
## for each VPC, leaving our own Route Tables as secondary

resource "aws_main_route_table_association" "main-rt-vpc-1" {
  vpc_id         = "${aws_vpc.vpc-1.id}"
  route_table_id = "${aws_route_table.vpc-1-rtb.id}"
}


#########################
# EC2 Instances Section #
#########################

# Key Pair

resource "aws_key_pair" "john-keypair" {
  key_name   = "john-keypair"
  public_key = "${var.public_key}"
}

# Security Groups

resource "aws_security_group" "sec-group-vpc-1-ssh-icmp" {
  name        = "${var.scenario}-sec-group-vpc-1-ssh-icmp"
  description = "test-tgw: Allow SSH and ICMP traffic"
  vpc_id      = "${aws_vpc.vpc-1.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27014
    to_port     = 27018
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
  }


  ingress {
    from_port   = 8 # the ICMP type number for 'Echo'
    to_port     = 0 # the ICMP code
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0 # the ICMP type number for 'Echo Reply'
    to_port     = 0 # the ICMP code
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sec-group-vpc-1-ssh-icmp"
    scenario = "${var.scenario}"
  }
}

# VMs

## Fetching AMI info
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "test-tgw-instance1-dev" {
  ami                         = "${data.aws_ami.ubuntu.id}"
 # ami                         = "${var.mongo-centos-ami}"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.vpc-1-sub-a.id}"
  vpc_security_group_ids     = [ "${aws_security_group.sec-group-vpc-1-ssh-icmp.id}" ]
  key_name                    = "${aws_key_pair.john-keypair.key_name}"
  private_ip                  = "10.10.1.10"
  associate_public_ip_address = true

  tags = {
    Name = "${var.scenario}-test-tgw-instance1-dev"
    scenario    = "${var.scenario}"
    env         = "dev"
    az          = "${var.az1}"
    vpc         = "1"
  }
}

provider "mongodbatlas" {
  public_key   = "${var.atlas-public-key}"
  private_key  = "${var.atlas-private-key}"
}

data "mongodbatlas_project" "aws_atlas" {
  name = "JOHNDOHONEY-AWS"
}


resource "mongodbatlas_network_peering" "myconn" {
  accepter_region_name   = "${var.atlas-region}"
  project_id             = "${var.atlas-project-id}"
  container_id           = "5dee84e9f2a30b6096cc837a"
  provider_name          = "${var.atlas-cloud-provider}"
  route_table_cidr_block = "${aws_vpc.vpc-1.cidr_block}"
  vpc_id                 = "${aws_vpc.vpc-1.id}"
  aws_account_id         = "${var.amazon-account-number}"

}

# the following assumes an AWS provider is configured  
resource "aws_vpc_peering_connection_accepter" "mypeer" {
  vpc_peering_connection_id = "${mongodbatlas_network_peering.myconn.connection_id}"
  auto_accept               = true

  depends_on = [ mongodbatlas_network_peering.myconn]
}

resource "mongodbatlas_project_ip_whitelist" "vpc-access" {
  project_id      = "${data.mongodbatlas_project.aws_atlas.id}"  
  cidr_block 	  	= "${var.mongodb_atlas_whitelistip}"
  comment     		= "VPC Access using private ip"
}

# Route Tables

resource "aws_route_table" "vpc-1-rtb" {
  vpc_id = "${aws_vpc.vpc-1.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.vpc-1-igw.id}"
  }

  route {
    cidr_block = "${var.atlas-aws-cidr}"
    gateway_id = "${mongodbatlas_network_peering.myconn.connection_id}"
  }

  tags = {
    Name       = "${var.scenario}-vpc-1-rtb"
    env        = "dev"
    scenario = "${var.scenario}"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.vpc-1-sub-a.id}"
  route_table_id = "${aws_route_table.vpc-1-rtb.id}"
}