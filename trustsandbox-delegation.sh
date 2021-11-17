# NOTE: these commands are supposed to run while inside the container
# trustsandbox-delegate
cd /root

export DOCKER_CONTENT_TRUST=0
docker pull docker/trusttest
export DOCKER_CONTENT_TRUST=1

openssl genrsa -out delegation.key 2048
openssl req -new -sha256 -key delegation.key -out delegation.csr <<EOF
FQDN = foo.example.org
ORGNAME = Example Org Name
ALTNAMES = DNS:$FQDN   # , DNS:bar.example.org , DNS:www.foo.example.org

[ req ]
default_bits = 2048
default_md = sha256
prompt = no
encrypt_key = no
distinguished_name = dn
req_extensions = req_ext

[ dn ]
C = CH
O = $ORGNAME
CN = $FQDN

[ req_ext ]
subjectAltName = $ALTNAMES
EOF

openssl x509 -req -sha256 -days 365 -in delegation.csr -signkey delegation.key -out delegation.crt
docker trust key load delegation.key --name delegation-name # use something like delegation-passphrase

cat delegation.crt

# try after adding delegation to server using admin

docker tag docker/trusttest registry:5000/collection/trusttest:latest
docker push registry:5000/collection/trusttest:latest
