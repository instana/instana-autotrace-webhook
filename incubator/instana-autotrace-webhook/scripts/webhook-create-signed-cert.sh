#!/bin/bash

## Based on https://raw.githubusercontent.com/banzaicloud/admission-webhook-example/blog/deployment/webhook-create-signed-cert.sh

set -e

usage() {
    cat <<EOF
Generate certificate suitable for use with an sidecar-injector webhook service.

This script uses k8s' CertificateSigningRequest API to a generate a
certificate signed by k8s CA suitable for use with sidecar-injector webhook
services. This requires permissions to create and approve CSR. See
https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster for
detailed explantion and additional instructions.

The server key/cert k8s CA cert are stored in a k8s secret.

usage: ${0} [OPTIONS]

The following flags are required.

       --service          Service name of webhook.
       --namespace        Namespace where webhook service and secret reside.
       --secret           Secret name for CA certificate and server certificate/key pair.
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case ${1} in
        --service)
            service="$2"
            shift
            ;;
        --secret)
            secret="$2"
            shift
            ;;
        --namespace)
            namespace="$2"
            shift
            ;;
        *)
            usage
            ;;
    esac
    shift
done

[ -z ${service} ] && service=instana-autotrace-webhook
[ -z ${secret} ] && secret=instana-autotrace-webhook-certs
[ -z ${namespace} ] && namespace=instana-autotrace-webhook

if [ ! -x "$(command -v openssl)" ]; then
    echo "openssl not found"
    exit 1
fi

csrName=${service}.${namespace}
tmpdir=$(mktemp -d)
echo -n "Creating certificates in tmpdir ${tmpdir}... "

cat <<EOF >> ${tmpdir}/csr.conf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${service}
DNS.2 = ${service}.${namespace}
DNS.3 = ${service}.${namespace}.svc
EOF

echo 'OK'

openssl genrsa -out ${tmpdir}/server-key.pem 2048 -name server
openssl req -new -key ${tmpdir}/server-key.pem -subj "/CN=${service}.${namespace}.svc" -out ${tmpdir}/server.csr -config ${tmpdir}/csr.conf

echo -n "Ensuring there is not previous Certificate Signing Request for the '${csrName}' service... "

# clean-up any previously created CSR for our service. Ignore errors if not present.
kubectl delete csr ${csrName} 2>/dev/null || true

echo 'OK'

echo -n "Creating Certificate Signing Request for the '${csrName}' service... "

# create  server cert/key CSR and  send to k8s API
cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${csrName}
spec:
  groups:
  - system:authenticated
  - system:nodes
  request: $(cat ${tmpdir}/server.csr | base64 | tr -d '\r\n' | tr -d '\n')
  # signerName: kubernetes.io/kubelet-serving # Kubernetes 1.18
  usages:
  - 'digital signature'
  - 'key encipherment'
  - 'server auth'
EOF

echo 'OK'

# verify CSR has been created
while true; do
    echo "Waiting for the Certificate Signing Request for the '${csrName}' service to be created... "

    kubectl get csr ${csrName}
    if [ "$?" -eq 0 ]; then
        break
    fi
done

echo -n "Approving and fetching the signed certificate for the '${csrName}' service... "

# approve and fetch the signed certificate
kubectl certificate approve ${csrName}
# verify certificate has been signed
for x in $(seq 10); do
    serverCert=$(kubectl get csr ${csrName} -o jsonpath='{.status.certificate}')
    if [[ ${serverCert} != '' ]]; then
        break
    fi
    sleep 1
done
if [[ ${serverCert} == '' ]]; then
    echo "ERROR: After approving csr ${csrName}, the signed certificate did not appear on the resource. Giving up after 10 attempts." >&2
    exit 1
fi

echo ${serverCert} | openssl base64 -d -A -out ${tmpdir}/server-cert.pem

echo 'OK'

echo "Creating the Kubernetes secret '${service}' in the '${namespace}' namespace... "

# create the secret with CA cert and server cert/key
kubectl create secret generic ${secret} \
        --from-file=tls.key=${tmpdir}/server-key.pem \
        --from-file=tls.crt=${tmpdir}/server-cert.pem \
        --dry-run -o yaml |
    kubectl -n ${namespace} apply -f -