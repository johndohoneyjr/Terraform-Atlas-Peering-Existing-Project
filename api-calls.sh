## New API


https://cloud.mongodb.com/api/atlas/v1.0/groups/5d656831c56c98173cf5af4b/containers

## Get All Containers
curl --user "<public Key>:<private key>" --digest \
  --header "Accept: application/json" \
  --request GET "https://cloud.mongodb.com/api/atlas/v1.0/groups/<group id>/containers?providerName=AWS&pretty=true"
