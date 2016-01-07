#!/bin/bash

mkdir certs
openssl genrsa -out certs/ca-key.pem 2048
openssl req -x509 -new -nodes -key certs/ca-key.pem -days 10000 -out certs/ca.pem -subj "/CN=kube-ca"
openssl genrsa -out certs/apiserver-key.pem 2048
openssl req -new -key certs/apiserver-key.pem -out certs/apiserver.csr -subj "/CN=kube-apiserver" -config certs/openssl.cnf
openssl x509 -req -in certs/apiserver.csr -CA certs/ca.pem -CAkey certs/ca-key.pem -CAcreateserial -out certs/apiserver.pem -days 365 -extensions v3_req -extfile certs/openssl.cnf
openssl genrsa -out certs/worker-key.pem 2048
openssl req -new -key certs/worker-key.pem -out certs/worker.csr -subj "/CN=kube-worker"
openssl x509 -req -in certs/worker.csr -CA certs/ca.pem -CAkey certs/ca-key.pem -CAcreateserial -out certs/worker.pem -days 365
openssl genrsa -out certs/admin-key.pem 2048
openssl req -new -key certs/admin-key.pem -out certs/admin.csr -subj "/CN=kube-admin"
openssl x509 -req -in certs/admin.csr -CA certs/ca.pem -CAkey certs/ca-key.pem -CAcreateserial -out certs/admin.pem -days 365
