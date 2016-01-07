#!/bin/bash

kubectl config set-cluster default-cluster --server=https://<MASTER_HOST> --certificate-authority=../openssl/certs/ca.pem
kubectl config set-credentials default-admin --certificate-authority=../openssl/certs/ca.pem --client-key=../openssl/certs/admin-key.pem --client-certificate=../openssl/certs/admin.pem
kubectl config set-context default-system --cluster=default-cluster --user=default-admin
kubectl config use-context default-system
rm setup_kubectl.sh
