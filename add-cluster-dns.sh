#!/bin/bash

# https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/
# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/12-dns-addon.md

#Deploying the DNS Cluster Add-on

kubectl create -f https://storage.googleapis.com/kubernetes-the-hard-way/kube-dns.yaml
kubectl get pods -l k8s-app=kube-dns -n kube-system

#verify DNS - use busybox 1.28.4 or newer; to avoid bug here:
# https://github.com/kubernetes/kubernetes/issues/66924
kubectl run busybox --image=busybox:1.28.4 --command -- sleep 3600
kubectl get pods -l run=busybox
POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")

kubectl exec -ti $POD_NAME -- nslookup kubernetes

#should get this:
#Server:    10.32.0.10
# Address 1: 10.32.0.10 kube-dns.kube-system.svc.cluster.local

# Name:      kubernetes
# Address 1: 10.32.0.1 kubernetes.default.svc.cluster.local