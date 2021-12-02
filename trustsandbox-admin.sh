# NOTE: these commands are supposed to run while inside the container
# trustsandbox-admin
notary init sandboxregistry:5000/collection/trusttest
notary publish sandboxregistry:5000/collection/trusttest

# rotate snapshot key immediately -- we are adding delegations
notary key rotate sandboxregistry:5000/collection/trusttest snapshot -r
notary publish sandboxregistry:5000/collection/trusttest

# after generating a delegation and obtaining a certificate

# change this certificate to the one that the delegation generates
echo "-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----" >> /root/delegation.pem

notary delegation add sandboxregistry:5000/collection/trusttest targets/delegation-name /root/delegation.pem --all-paths
notary publish sandboxregistry:5000/collection/trusttest
