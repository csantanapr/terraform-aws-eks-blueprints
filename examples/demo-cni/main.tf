module "team1" {
  source  = "../vpc-cni-custom-networking"
  name = "team1"
  region = "us-west-2"
  vpc_cidr = "10.0.0.0/16"
  secondary_vpc_cidr = "100.64.0.0/16"
  domain_name = "demo1.cloud-native-start.com"
}

module "team2" {
  source  = "../vpc-cni-custom-networking"
  name = "team2"
  region = "us-west-2"
  vpc_cidr = "10.1.0.0/16"
  secondary_vpc_cidr = "100.64.0.0/16"
  domain_name = "demo2.cloud-native-start.com"
}

