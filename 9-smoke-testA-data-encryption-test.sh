#!/bin/bash
#https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/13-smoke-test.md#data-encryption

kubectl create secret generic kubernetes-the-hard-way \
  --from-literal="mykey=mydata"

ssh -i ssh/kubernetes.id_rsa ubuntu@(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=controller-0" \
  --output text --query 'Reservations[].Instances[].PublicIpAddress') \
  "ETCDCTL_API=3 etcdctl get /registry/secrets/default/kubernetes-the-hard-way | hexdump -C"

  #The etcd key should be prefixed with k8s:enc:aescbc:v1:key1, 
  #which indicates the aescbc provider was used to encrypt the data with the key1 encryption key.
 