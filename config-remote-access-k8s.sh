#!/bin/bash
# get your ${KUBERNETES_PUBLIC_ADDRESS} for later

#run on your machine (not controller or worker)- config kubectl
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=tls/ca.pem \
  --embed-certs=true \
  --server=https://kubernetes-c524c0cb8e26c401.elb.us-west-2.amazonaws.com:6443

kubectl config set-credentials admin \
  --client-certificate=tls/admin.pem \
  --client-key=tls/admin-key.pem

kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin

kubectl config use-context kubernetes-the-hard-way

#----
kubectl get componentstatuses
kubectl get nodes

