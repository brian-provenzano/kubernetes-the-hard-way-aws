#!/bin/bash
#In this section you will verify the ability to create and manage Deployments.

#---Create a deployment for the nginx web server:
kubectl run nginx --image=nginx
#list pods
kubectl get pods -l run=nginx

#--port forwarding
POD_NAME=$(kubectl get pods -l run=nginx -o jsonpath="{.items[0].metadata.name}")
#Forward port 8080 on your local machine to port 80 of the nginx pod:
kubectl port-forward $POD_NAME 8080:80
#In a new terminal make an HTTP request using the forwarding address:
curl --head http://127.0.0.1:8080
#Switch back to the previous terminal and stop the port forwarding to the nginx pod:

#--logs
#print nginx pod logs
kubectl logs $POD_NAME

#--execute commands in the nginx container
kubectl exec -ti $POD_NAME -- nginx -v

#--services - create a service
kubectl expose deployment nginx --port 80 --type NodePort

#node port of the service
NODE_PORT=$(kubectl get svc nginx \
  --output=jsonpath='{range .spec.ports[0]}{.nodePort}')

#to get ${SECURITY_GROUP_ID} of your k8s cluster - run describe security groups as noted below
aws ec2 describe-security-groups
aws ec2 describe-security-groups --group-id sg-<id-of-your-k8sgrp>

aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol tcp \
  --port ${NODE_PORT} \
  --cidr 0.0.0.0/0

EXTERNAL_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=worker-1" \
  --output text --query 'Reservations[].Instances[].PublicIpAddress')

#test the access to the exposed service
  curl -I http://${EXTERNAL_IP}:${NODE_PORT}