#!/bin/bash
# Author: Brian Provenzano
#
# Thanks to https://github.com/slawekzachcial/kubernetes-the-hard-way-aws
# Using this to walk through the turorial and capture the commands
# as I complete the setup.
# ------
# !! Yes I know the Terraform files in the original repo do this already, 
# but it forces some learning through doing :) !!

TAG="kubernetes-the-hard-way"
AWS_REGION=us-west-2
VPC_ID=""
DHCP_OPTION_SET_ID=""
SUBNET_ID=""
INTERNET_GATEWAY_ID=""
ROUTE_TABLE_ID=""
SECURITY_GROUP_ID=""
LOAD_BALANCER_ARN=""
TARGET_GROUP_ARN=""
KUBERNETES_PUBLIC_ADDRESS=""

echo "This script will create k8s cluster on AWS using 'kubernetes-the-hard-way' tutorial..."
echo "https://github.com/slawekzachcial/kubernetes-the-hard-way-aws"
echo "https://github.com/kelseyhightower/kubernetes-the-hard-way"

echo "Create Networking?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.240.0.0/24 \
  --output text --query 'Vpc.VpcId') \
 && aws ec2 create-tags  \
  --resources ${VPC_ID} \
  --tags Key=Name,Value=${TAG} \
&& aws ec2 modify-vpc-attribute  \
  --vpc-id ${VPC_ID} \
  --enable-dns-support '{"Value": true}' \
&& aws ec2 modify-vpc-attribute  \
  --vpc-id ${VPC_ID} \
  --enable-dns-hostnames '{"Value": true}' \
#DHCP OPTION SETS
&& DHCP_OPTION_SET_ID=$(aws ec2 create-dhcp-options \
  --dhcp-configuration \
    "Key=domain-name,Values=$AWS_REGION.compute.internal" \
    "Key=domain-name-servers,Values=AmazonProvidedDNS" \
  --output text --query 'DhcpOptions.DhcpOptionsId') \
&& aws ec2 create-tags \
  --resources ${DHCP_OPTION_SET_ID} \
  --tags Key=Name,Value=${TAG}
&& aws ec2 associate-dhcp-options \
  --dhcp-options-id ${DHCP_OPTION_SET_ID} \
  --vpc-id ${VPC_ID} \
#SUBNETS
&& SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id ${VPC_ID} \
  --cidr-block 10.240.0.0/24 \
  --output text --query 'Subnet.SubnetId') \
&& aws ec2 create-tags \
  --resources ${SUBNET_ID} \
  --tags Key=Name,Value=${TAG} \
#IGW
&& INTERNET_GATEWAY_ID=$(aws ec2 create-internet-gateway \
  --output text --query 'InternetGateway.InternetGatewayId') \
&& aws ec2 create-tags \
  --resources ${INTERNET_GATEWAY_ID} \
  --tags Key=Name,Value=kubernetes \
&& aws ec2 attach-internet-gateway \
  --internet-gateway-id ${INTERNET_GATEWAY_ID} \
  --vpc-id ${VPC_ID} \
#ROUTE TABLES
&& ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id ${VPC_ID} \
  --output text --query 'RouteTable.RouteTableId') \
&& aws ec2 create-tags \
  --resources ${ROUTE_TABLE_ID} \
  --tags Key=Name,Value=${TAG}
&& aws ec2 associate-route-table \
  --route-table-id ${ROUTE_TABLE_ID} \
  --subnet-id ${SUBNET_ID} \
&& aws ec2 create-route \
  --route-table-id ${ROUTE_TABLE_ID} \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id ${INTERNET_GATEWAY_ID} \
#SECURITY GROUPS
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
  --group-name kubernetes \
  --description "Kubernetes security group" \
  --vpc-id ${VPC_ID} \
  --output text --query 'GroupId') \
&& aws ec2 create-tags \
  --resources ${SECURITY_GROUP_ID} \
  --tags Key=Name,Value=${TAG} \
&& aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol all \
  --cidr 10.240.0.0/24 \
&& aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol all \
  --cidr 10.200.0.0/16 \
&& aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 \ 
&& aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol tcp \
  --port 6443 \
  --cidr 0.0.0.0/0 \
&& aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol icmp \
  --port -1 \
  --cidr 0.0.0.0/0 \
#K8S PUBLIC ADDRESS (ALB etc)
&& LOAD_BALANCER_ARN=$(aws elbv2 create-load-balancer \
  --name kubernetes \
  --subnets ${SUBNET_ID} \
  --scheme internet-facing \
  --type network \
  --output text --query 'LoadBalancers[].LoadBalancerArn') \
#BJP -added tag on ALB that is not in original tutorial
&& aws elbv2 add-tags \
  --resource-arns ${LOAD_BALANCER_ARN} \
  --tags  ${TAG} \
&& TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
  --name kubernetes \
  --protocol TCP \
  --port 6443 \
  --vpc-id ${VPC_ID} \
  --target-type ip \
  --output text --query 'TargetGroups[].TargetGroupArn') \
&& aws elbv2 register-targets \
  --target-group-arn ${TARGET_GROUP_ARN} \
  --targets Id=10.240.0.1{0,1,2} \
&& ALB_LISTENER_ARN= $(aws elbv2 create-listener \
  --load-balancer-arn ${LOAD_BALANCER_ARN} \
  --protocol TCP \
  --port 6443 \
  --default-actions Type=forward,TargetGroupArn=${TARGET_GROUP_ARN} \
  --output text --query 'Listeners[].ListenerArn') \
&& KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns ${LOAD_BALANCER_ARN} \
  --output text --query 'LoadBalancers[].DNSName'); break;;
        No ) exit;;
    esac
done
echo "Networking Created! "
echo "Details ---> \n"
aws ec2 describe-vpcs --vpc-ids ${VPC_ID}
aws ec2 describe-subnets --subnet-ids ${SUBNET_ID}
aws ec2 describe-internet-gateways --internet-gateway-ids ${INTERNET_GATEWAY_ID}
aws ec2 describe-route-tables --route-table-ids ${ROUTE_TABLE_ID}
aws ec2 describe-security-groups --group-ids ${SECURITY_GROUP_ID}
aws elbv2 describe-load-balancers --load-balancer-arns ${LOAD_BALANCER_ARN}
aws elbv2 describe-listeners --load-balancer-arns ${LOAD_BALANCER_ARN} --listener-arns ${ALB_LISTENER_ARN}

