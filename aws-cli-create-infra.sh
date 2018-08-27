#!/bin/bash

echo "This script will create k8s cluster on AWS using 'kubernetes-the-hard-way' tutorial..."
echo "https://github.com/slawekzachcial/kubernetes-the-hard-way-aws"
echo "https://github.com/kelseyhightower/kubernetes-the-hard-way"

echo "Create the VPC?"
VPC_ID=""
select yn in "Yes" "No"; do
    case $yn in
        Yes ) VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.240.0.0/24 \
  --output text --query 'Vpc.VpcId') \
 && aws ec2 create-tags  \
  --resources ${VPC_ID} \
  --tags Key=Name,Value=kubernetes-the-hard-way \
&& aws ec2 modify-vpc-attribute  \
  --vpc-id ${VPC_ID} \
  --enable-dns-support '{"Value": true}' \
&& aws ec2 modify-vpc-attribute  \
  --vpc-id ${VPC_ID} \
  --enable-dns-hostnames '{"Value": true}'; break;;
        No ) exit;;
    esac
done
echo "VPC Created! VPC details :"
aws ec2 describe-vpcs --vpc-ids $VPC_ID
