MongoDB Atlas Peering using and Existing Project
===========================================

Most of the Terraform Network Peering examples do not utilize an existing Atlas Project (Group).  This is an important detail, as there is an existing Network Container.  These containers exist within a Project/Group and are established by region

Determining your Network Container
--------------

Curl call:
```
curl --user "<privateKey>:<publickey>" --digest --header "Accept: application/json" --request GET "https://cloud.mongodb.com/api/atlas/v1.0/groups/<project id>/containers?providerName=AWS&pretty=true"
```

```
Call Response:
{
  "links" : [ {
    "href" : "https://cloud.mongodb.com/api/atlas/v1.0/groups/5d656831c56c98173cf5af4b/containers?providerName=AWS&pretty=true&pageNum=1&itemsPerPage=100",
    "rel" : "self"
  } ],
  "results" : [ {
    "atlasCidrBlock" : "192.168.240.0/21",
    "id" : "5dee84e9f2a30b6096cc837a",
    "providerName" : "AWS",
    "provisioned" : true,
    "regionName" : "US_WEST_2",
    "vpcId" : "vpc-0930f852caef2a33d"
  }, {
    "atlasCidrBlock" : "192.168.248.0/21",
    "id" : "5f297c7bc3495a7cb57473cf",
    "providerName" : "AWS",
    "provisioned" : false,
    "regionName" : "US_EAST_1",
    "vpcId" : null
  }, {
    "atlasCidrBlock" : "192.168.232.0/21",
    "id" : "5f29f95c3226fa324d1c34b6",
    "providerName" : "AWS",
    "provisioned" : true,
    "regionName" : "US_EAST_2",
    "vpcId" : "vpc-05087af6e283b32dc"
  } ],
  "totalCount" : 3

```
# Populating the Terraform Resource
Since in this example, we are using US_WEST_2 (Atlas Syntax), we have to fill in the **container_id** for the Peering Resource.
```
resource  "mongodbatlas_network_peering"  "myconn" {
  accepter_region_name =  "${var.atlas-region}"
  project_id =  "${var.atlas-project-id}"
  container_id = "5dee84e9f2a30b6096cc837a"
  provider_name =  "${var.atlas-cloud-provider}"
  route_table_cidr_block =  "${aws_vpc.vpc-1.cidr_block}"
  vpc_id =  "${aws_vpc.vpc-1.id}"
  aws_account_id =  "${var.amazon-account-number}"
}
```

We use the Peering acceptor as this would be part of a CI pipeline, to auto-accept the peering request
```
resource  "aws_vpc_peering_connection_accepter"  "mypeer" {
  vpc_peering_connection_id =  "${mongodbatlas_network_peering.myconn.connection_id}"
  auto_accept =  true
  depends_on =  [ mongodbatlas_network_peering.myconn]
}
```

The last part is to stitch the Peering Connection and Internet Gateway into the Route Table

```
resource  "aws_route_table"  "vpc-1-rtb" {
  vpc_id =  "${aws_vpc.vpc-1.id}"
  route {
    cidr_block =  "0.0.0.0/0"
    gateway_id =  "${aws_internet_gateway.vpc-1-igw.id}"
}
route {
  cidr_block =  "${var.atlas-aws-cidr}"
  gateway_id =  "${mongodbatlas_network_peering.myconn.connection_id}"
}
tags =  {
  Name  =  "${var.scenario}-vpc-1-rtb"
  env  =  "dev"
  scenario  =  "${var.scenario}"
  }
}

resource  "aws_route_table_association"  "a" {
  subnet_id =  "${aws_subnet.vpc-1-sub-a.id}"
  route_table_id =  "${aws_route_table.vpc-1-rtb.id}"
 }
```

Final Thoughts
------------

The execution of the Network Peering is fast, however, the underlying provisioning can take upwards of 15-25 mins when the cloud provider is busy.  Grab some coffee, a lot is being done behind the scenes to establish this connection.

