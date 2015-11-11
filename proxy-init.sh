#!/bin/bash
set -ex

PREFIX=s3://devops.magv.com/launch-config/tlsproxy

# obtain TLS connection options
aws s3 cp --region ${NODE_REGION} ${PREFIX}/ca.pem /cert/ca.pem
aws s3 cp --region ${NODE_REGION} ${PREFIX}/server-key.pem /cert/server-key.pem
aws s3 cp --region ${NODE_REGION} ${PREFIX}/server-cert.pem /cert/server-cert.pem

# download trusted cert and hash
mkdir -p /trusted
rm -f /trusted/*
aws s3 cp --region ${NODE_REGION} ${PREFIX}/cert.pem /trusted/cert.pem
HASHVALUE=$(openssl x509 -noout -hash -in /trusted/cert.pem)
ln -s /trusted/cert.pem /trusted/${HASHVALUE}.0

URL="https://raw.githubusercontent.com/AndrewMagv/aws-devops/${REF}/tlsproxy"
while [ $# -gt 0 ]; do
    curl -sSL ${URL}/${1}.conf >>/proxy.conf
    shift 1 # moving along
done
