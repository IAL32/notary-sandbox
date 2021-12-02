# Notary Sandbox

This small repository stems from the fact that the [Docker Content Trust documentation](https://docs.docker.com/engine/security/trust/trust_sandbox/) is very, very outdated. What we are doing is basically creating a small sandbox environment where we have:

- A registry (`registry:2.7`)
- A Notary Signer (`notary:signer-0.6.1-2`)
- A Notary Server (`notary:server-0.6.1-2`)
- A Notary CLI client (administrator) (`docker:dind`)
- A Docker CLI client (delegate) (`docker:dind`)

We try to show how Notary works, how to interact with the Notary Server with the Notary CLI (as a system administrator) and with the Docker CLI (as a delegate).

## Prerequisites

You need Docker and `docker-compose` installed. That's pretty much it.

## Configuration

Just clone this repository locally with

```
git clone git@github.com:IAL32/notary-sandbox.git --recursive
```

Then enter the directory and launch `docker-compose`

```
cd notary-sandbox
docker-compose up
```

## Playing in the sandbox

After the containers have spawned, you should be able to perform some operations on Notary Server right away. Please refer to the [official Notary documentation](https://github.com/notaryproject/notary/tree/master/docs) for a better understanding of how Notary works.

### Initializing Notary

In this repository, operations that are meant to be executed using the Notary CLI (`notary <command>`) are run inside the container `trustsandbox-admin`. You can log in to this container with:

```
docker exec -it trustsandbox-admin sh -l
```

First, we need to initialize our keys. From inside the container, run

```
notary init sandboxregistry:5000/collection/trusttest
notary publish sandboxregistry:5000/collection/trusttest
```

Note that no passphrase will be asked. Normally, the Notary CLI will ask you to insert the passphrases for *root*, *targets* and *snapshot* roles. However, in [`docker-compose.yml`](https://github.com/IAL32/notary-sandbox/blob/main/docker-compose.yml) we have defined the following environment variables:

- `NOTARY_ROOT_PASSPHRASE`
- `NOTARY_TARGETS_PASSPHRASE`
- `NOTARY_SNAPSHOT_PASSPHRASE`

The Notary CLI will automatically use these passphrases to perform all operations that require the use of their relevant keys.

### Rotating the snapshot key

[As stated in the official documentation](https://github.com/notaryproject/notary/blob/master/docs/best_practices.md#snapshot-key), we rotate the snapshot key to the Notary Signer for convenience. To do so, use:

```
notary key rotate sandboxregistry:5000/collection/trusttest snapshot -r
```

There is no need to launch `notary publish <GUN>`, as the operation will be performed directly on the Notary Signer thanks to the `-r` flag.

### Creating a delegation

If there is only one party that performs signing operations (such as a Jenkins job agent), then adding delegates to GUNs is not really necessary. However, if you have more than one party, such as collaborators in a team, then you need to create delegations.

To add delegations, the Notary Server needs to obtain the delegates certificates, that will then be used to verify signing operations.

#### Delegate side

All operations performed by a delegate will be run inside the `trustsandbox-delegate` container, to which you can log in with:

```
docker exec -it trustsandbox-delegate sh -l
```

Also, we will assume that delegates do not have access (and do not need) to a Notary client. Every operation that they need to perform is already implemented by the Docker CLI.

A simple, self-signed certificate can be generated with:

```bash
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
```

Now you can load the delegation private key into your local trust storage with:

```
docker trust key load delegation.key --name <your-name>
```

The Docker CLI will ask you to encrypt the key with a passphrase. Store the passphrase in a secure place.

#### Admin side

The administrator, which holds the *targets* key, used to add delegates, then needs to trust the certificate provided by the delegate. The certificate from the previous section can be obtained by just launching

```
# cat delegation.crt

-----BEGIN CERTIFICATE-----
<certificate-contents>
-----END CERTIFICATE-----
```

This delegation can then be saved directly into a file `delegation.pem` inside the `trustsandbox-admin` container with:

```
echo "-----BEGIN CERTIFICATE-----
<certificate-contents>
-----END CERTIFICATE-----" >> /root/delegation.pem
```

And then add the delegation to the trusted certificates with:

```
notary delegation add sandboxregistry:5000/collection/trusttest targets/delegation-name /root/delegation.pem --all-paths
notary publish sandboxregistry:5000/collection/trusttest
```

### Pushing images

Now the delegate can tag, push and sign images to the registry and the Notary Server.

However, if you try right away to pull a test image (`docker/trusttest` for example) while inside the `trustsandbox-delegate` container, you will get an error like:

```
# docker pull docker/trusttest
Using default tag: latest
Error: remote trust data does not exist for docker.io/docker/trusttest: notaryserver:4443 does not have trust data for docker.io/docker/trusttest
```

This is because in [`docker-compose.yml`](https://github.com/IAL32/notary-sandbox/blob/main/docker-compose.yml) we have defined the following environment variables:

- `DOCKER_CONTENT_TRUST=1`
- `DOCKER_CONTENT_TRUST_SERVER=https://notaryserver:4443`

And suddenly the error makes total sense. Our Notary server does not hold any information (yet) about that image.

To pull an image from the official `docker.io` registry, we need to disable DCT temporarily by setting:

```
export DOCKER_CONTENT_TRUST=0
```

This will allow us to pull the image from the `docker.io` registry without any checks for signatures. After pulling, we can set it back to:

```
export DOCKER_CONTENT_TRUST=1
```

Tag, and push the image to our registry:

```
docker tag docker/trusttest sandboxregistry:5000/collection/trusttest:latest
docker push sandboxregistry:5000/collection/trusttest:latest
```

And it's done!
