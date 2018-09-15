#!/bin/bash
# Author: Brian Provenzano
#
# -Added 'aws elbv2 add-tags' to add tag to the ALB
#
# Thanks to https://github.com/slawekzachcial/kubernetes-the-hard-way-aws
# Using this to walk through the turorial and capture the commands
# as I complete the setup.
# ------
# !! Yes I know the Terraform files in the original repo do this already, 
# but it forces some learning through doing :) !!
set -e

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
IMAGE_ID=""

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
&& DHCP_OPTION_SET_ID=$(aws ec2 create-dhcp-options \
  --dhcp-configuration \
    "Key=domain-name,Values=$AWS_REGION.compute.internal" \
    "Key=domain-name-servers,Values=AmazonProvidedDNS" \
  --output text --query 'DhcpOptions.DhcpOptionsId') \
&& aws ec2 create-tags \
  --resources ${DHCP_OPTION_SET_ID} \
  --tags Key=Name,Value=${TAG} \
&& aws ec2 associate-dhcp-options \
  --dhcp-options-id ${DHCP_OPTION_SET_ID} \
  --vpc-id ${VPC_ID} \
&& SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id ${VPC_ID} \
  --cidr-block 10.240.0.0/24 \
  --output text --query 'Subnet.SubnetId') \
&& aws ec2 create-tags \
  --resources ${SUBNET_ID} \
  --tags Key=Name,Value=${TAG} \
&& INTERNET_GATEWAY_ID=$(aws ec2 create-internet-gateway \
  --output text --query 'InternetGateway.InternetGatewayId') \
&& aws ec2 create-tags \
  --resources ${INTERNET_GATEWAY_ID} \
  --tags Key=Name,Value=${TAG} \
&& aws ec2 attach-internet-gateway \
  --internet-gateway-id ${INTERNET_GATEWAY_ID} \
  --vpc-id ${VPC_ID} \
&& ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id ${VPC_ID} \
  --output text --query 'RouteTable.RouteTableId') \
&& aws ec2 create-tags \
  --resources ${ROUTE_TABLE_ID} \
  --tags Key=Name,Value=${TAG} \
&& aws ec2 associate-route-table \
  --route-table-id ${ROUTE_TABLE_ID} \
  --subnet-id ${SUBNET_ID} \
&& aws ec2 create-route \
  --route-table-id ${ROUTE_TABLE_ID} \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id ${INTERNET_GATEWAY_ID} \
&& SECURITY_GROUP_ID=$(aws ec2 create-security-group \
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
&& LOAD_BALANCER_ARN=$(aws elbv2 create-load-balancer \
  --name kubernetes \
  --subnets ${SUBNET_ID} \
  --scheme internet-facing \
  --type network \
  --output text --query 'LoadBalancers[].LoadBalancerArn') \
&& aws elbv2 add-tags \
  --resource-arns ${LOAD_BALANCER_ARN} \
  --tags Key=Name,Value=${TAG} \
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
&& ALB_LISTENER_ARN=$(aws elbv2 create-listener \
  --load-balancer-arn ${LOAD_BALANCER_ARN} \
  --protocol TCP \
  --port 6443 \
  --default-actions Type=forward,TargetGroupArn=${TARGET_GROUP_ARN} \
  --output text --query 'Listeners[].ListenerArn') \
&& KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns ${LOAD_BALANCER_ARN} \
  --output text --query 'LoadBalancers[0].DNSName'); break;;
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
aws elbv2 describe-listeners --load-balancer-arn ${LOAD_BALANCER_ARN}
echo -e "----\nK8s public address: ${KUBERNETES_PUBLIC_ADDRESS} \n----"

echo "Create Compute?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) IMAGE_ID=$(aws ec2 describe-images --owners 099720109477 \
  --filters \
  'Name=root-device-type,Values=ebs' \
  'Name=architecture,Values=x86_64' \
  'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*' \
  | jq -r '.Images|sort_by(.Name)[-1]|.ImageId') \
&& mkdir -p ssh && aws ec2 create-key-pair \
  --key-name kubernetes \
  --output text --query 'KeyMaterial' \
  > ssh/kubernetes.id_rsa \
&& chmod 600 ssh/kubernetes.id_rsa \
&& for i in 0 1 2; do
  INSTANCE_ID=$(aws ec2 run-instances \
    --associate-public-ip-address \
    --image-id ${IMAGE_ID} \
    --count 1 \
    --key-name kubernetes \
    --security-group-ids ${SECURITY_GROUP_ID} \
    --instance-type t2.micro \
    --private-ip-address 10.240.0.1${i} \
    --user-data "name=controller-${i}" \
    --subnet-id ${SUBNET_ID} \
    --output text --query 'Instances[].InstanceId')
  aws ec2 modify-instance-attribute \
    --instance-id ${INSTANCE_ID} \
    --no-source-dest-check
  aws ec2 create-tags \
    --resources ${INSTANCE_ID} \
    --tags "Key=Name,Value=controller-${i}"
done \
&& for i in 0 1 2; do
  INSTANCE_ID=$(aws ec2 run-instances \
    --associate-public-ip-address \
    --image-id ${IMAGE_ID} \
    --count 1 \
    --key-name kubernetes \
    --security-group-ids ${SECURITY_GROUP_ID} \
    --instance-type t2.micro \
    --private-ip-address 10.240.0.2${i} \
    --user-data "name=worker-${i}|pod-cidr=10.200.${i}.0/24" \
    --subnet-id ${SUBNET_ID} \
    --output text --query 'Instances[].InstanceId')
  aws ec2 modify-instance-attribute \
    --instance-id ${INSTANCE_ID} \
    --no-source-dest-check
  aws ec2 create-tags \
    --resources ${INSTANCE_ID} \
    --tags "Key=Name,Value=worker-${i}"
done; 
break;;
        No ) exit;;
    esac
done

# Provisioning a CA and Generating TLS certificates
echo "Sleep/wait until instances are started..."
sleep 60
echo "Create / Provision CA and generate TLS certificates..."
mkdir -p tls
#Certificate Authority
echo "Certificate Authority..."
cat > tls/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
cat > tls/ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Denver",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Colorado"
    }
  ]
}
EOF
cfssl gencert -initca tls/ca-csr.json | cfssljson -bare tls/ca

# Admin Client Certificate
echo "Gen the Admin Client Certificate..."
cat > tls/admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Denver",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Colorado"
    }
  ]
}
EOF
cfssl gencert \
  -ca=tls/ca.pem \
  -ca-key=tls/ca-key.pem \
  -config=tls/ca-config.json \
  -profile=kubernetes \
  tls/admin-csr.json | cfssljson -bare tls/admin

# Kubelet Client Certificates
echo "Gen the Kubelet Client Certificates..."
for i in 0 1 2; do
  instance="worker-${i}"
  instance_hostname="ip-10-240-0-2${i}"
  cat > tls/${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance_hostname}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Denver",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Colorado"
    }
  ]
}
EOF
  external_ip=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')

  internal_ip=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PrivateIpAddress')

  cfssl gencert \
    -ca=tls/ca.pem \
    -ca-key=tls/ca-key.pem \
    -config=tls/ca-config.json \
    -hostname=${instance_hostname},${external_ip},${internal_ip} \
    -profile=kubernetes \
    tls/worker-${i}-csr.json | cfssljson -bare tls/worker-${i}
done

#kube-proxy Client Certificate
echo "Gen the kube-proxy Client Certificate..."
cat > tls/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Denver",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Colorado"
    }
  ]
}
EOF
cfssl gencert \
  -ca=tls/ca.pem \
  -ca-key=tls/ca-key.pem \
  -config=tls/ca-config.json \
  -profile=kubernetes \
  tls/kube-proxy-csr.json | cfssljson -bare tls/kube-proxy

# Kubernetes API Server Certificate
echo "Gen the K8s API Server Certificate..."
cat > tls/kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Denver",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Colorado"
    }
  ]
}
EOF
cfssl gencert \
  -ca=tls/ca.pem \
  -ca-key=tls/ca-key.pem \
  -config=tls/ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,ip-10-240-0-10,ip-10-240-0-11,ip-10-240-0-12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  tls/kubernetes-csr.json | cfssljson -bare tls/kubernetes

#Distribute the Client and Server Certificates
echo "Distribute the Client and Server Certificates..."
for instance in worker-0 worker-1 worker-2; do
  external_ip=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')
  scp -v -o StrictHostkeyChecking=no -o UserKnownHostsFile=/dev/null -i ssh/kubernetes.id_rsa \
    tls/ca.pem tls/${instance}-key.pem tls/${instance}.pem \
    ubuntu@${external_ip}:~/
done 
for instance in controller-0 controller-1 controller-2; do
  external_ip=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')
  scp -v -o StrictHostkeyChecking=no -o UserKnownHostsFile=/dev/null-i ssh/kubernetes.id_rsa \
    tls/ca.pem tls/ca-key.pem tls/kubernetes-key.pem tls/kubernetes.pem \
    ubuntu@${external_ip}:~/
done

# Generating Kubernetes Authentication Files for Authentication
echo "Generating Kubernetes Authentication Files for Authentication..."
echo -e "----\nCurrent K8s Public IP Address: ${KUBERNETES_PUBLIC_ADDRESS} \n----"
# The kubelet Kubernetes Configuration Files
echo "The kubelet Kubernetes Configuration Files..."
mkdir -p cfg
for i in 0 1 2; do
  instance="worker-${i}"
  instance_hostname="ip-10-240-0-2${i}"
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=tls/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=cfg/${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance_hostname} \
    --client-certificate=tls/${instance}.pem \
    --client-key=tls/${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=cfg/${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance_hostname} \
    --kubeconfig=cfg/${instance}.kubeconfig

  kubectl config use-context default \
    --kubeconfig=cfg/${instance}.kubeconfig
done

#The kube-proxy Kubernetes Configuration File
echo "The kube-proxy Kubernetes Configuration File..."
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=tls/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=cfg/kube-proxy.kubeconfig
kubectl config set-credentials kube-proxy \
  --client-certificate=tls/kube-proxy.pem \
  --client-key=tls/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=cfg/kube-proxy.kubeconfig
kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=kube-proxy \
  --kubeconfig=cfg/kube-proxy.kubeconfig
kubectl config use-context default \
  --kubeconfig=cfg/kube-proxy.kubeconfig

#Distribute the Kubernetes Configuration Files
echo "Distribute the Kubernetes Configuration Files to the instances..."
for instance in worker-0 worker-1 worker-2; do
  external_ip=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')
  scp -v -o StrictHostkeyChecking=no -o UserKnownHostsFile=/dev/null -i ssh/kubernetes.id_rsa \
    cfg/${instance}.kubeconfig cfg/kube-proxy.kubeconfig \
    ubuntu@${external_ip}:~/
done

#Generating the Data Encryption Config and Key
echo "Generating the Data Encryption Config and Key..."
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
cat > cfg/encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
for instance in controller-0 controller-1 controller-2; do
  external_ip=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')
  scp -v -o StrictHostkeyChecking=no -o UserKnownHostsFile=/dev/null -i ssh/kubernetes.id_rsa cfg/encryption-config.yaml ubuntu@${external_ip}:~/
done

#DONE - rest is manual labor :)
echo "-----------------------------------------------------"
echo "Continue tutorial at 'Bootstrapping the etcd Cluster' - rest is manual bootstrap and config of the cluster"
echo "-----------------------------------------------------"



#CLEANUP ---------------
echo "K8s Cluster up and running ... when you are ready to cleanup continue as noted"
echo "Cleanup/ Destroy all AWS resources in use?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) aws ec2 terminate-instances \
  --instance-ids \
    $(aws ec2 describe-instances \
      --filter "Name=tag:Name,Values=controller-0,controller-1,controller-2,worker-0,worker-1,worker-2" \
      --output text --query 'Reservations[].Instances[].InstanceId') \
&& aws ec2 delete-key-pair \
  --key-name kubernetes \
&& aws elbv2 delete-load-balancer \
  --load-balancer-arn "${LOAD_BALANCER_ARN}" \
&& aws elbv2 delete-target-group \
  --target-group-arn "${TARGET_GROUP_ARN}" \
&& ROUTE_TABLE_ASSOCIATION_ID="$(aws ec2 describe-route-tables \
  --route-table-ids "${ROUTE_TABLE_ID}" \
  --output text --query 'RouteTables[].Associations[].RouteTableAssociationId')" \
&& aws ec2 disassociate-route-table \
  --association-id "${ROUTE_TABLE_ASSOCIATION_ID}" \
&& aws ec2 delete-route-table \
  --route-table-id "${ROUTE_TABLE_ID}" \
&& echo "sleeping 1 min to let LB dissassociate before detaching IGW..." && sleep 60 \
&& aws ec2 detach-internet-gateway \
  --internet-gateway-id "${INTERNET_GATEWAY_ID}" \
  --vpc-id "${VPC_ID}" \
&& aws ec2 delete-internet-gateway \
  --internet-gateway-id "${INTERNET_GATEWAY_ID}" \
&& aws ec2 delete-subnet \
  --subnet-id "${SUBNET_ID}" \
&& aws ec2 delete-vpc \
  --vpc-id "${VPC_ID}" \
&& sleep 20 \
&& aws ec2 delete-dhcp-options \
  --dhcp-options-id "${DHCP_OPTION_SET_ID}" \
&& aws ec2 delete-security-group \
  --group-id "${SECURITY_GROUP_ID}" && printenv; break;;
        No ) exit;;
    esac
done

echo "Cleanup ssh/tls/cfg directories as well?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) rm -fr tls && rm -fr ssh && rm -fr cfg; break;;
        No ) exit;;
    esac
done