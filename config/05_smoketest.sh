#!/bin/bash

kubectl create secret generic kubernetes-the-hard-way \
  --from-literal="mykey=mydata"

kubectl create deployment nginx --image=nginx

kubectl expose deployment nginx --port 80 --type NodePort
