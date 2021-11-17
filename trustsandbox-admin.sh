# NOTE: these commands are supposed to run while inside the container
# trustsandbox-admin
notary init registry:5000/collection/trusttest
notary publish registry:5000/collection/trusttest

# rotate snapshot key immediately -- we are adding delegations
notary key rotate registry:5000/collection/trusttest snapshot -r
notary publish registry:5000/collection/trusttest

# after generating a delegation and obtaining a certificate

# change this certificate to the one that the delegation generates
echo "-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----" >> /root/delegation.pem

notary delegation add registry:5000/collection/trusttest targets/delegation-name /root/delegation.pem --all-paths
notary publish registry:5000/collection/trusttest
