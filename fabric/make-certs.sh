#!/bin/sh
# make-certs.sh — the stand-in for a goatnet's certificate authority.
#
#   make-certs.sh <directory> <slot UUID>...
#
# On a goatnet you never do this: the goatnet's portal mints your certificate
# and hands it over in an onboarding archive. This script exists so that step 4
# has a complete authority to run against with no goatnet. It writes, into
# <directory>:
#   ca-root.pem, ca.key          a throwaway root, valid two days
#   router-cert.pem, -key.pem    the router's certificate, for 127.0.0.1 and the name localhost
#   <slot>-cert.pem, -key.pem    one client certificate per slot UUID, whose
#                                common name is the UUID, as goat mints them
set -eu
dir="$1"; shift
mkdir -p "$dir"; cd "$dir"

openssl ecparam -name prime256v1 -genkey -noout -out ca.key 2>/dev/null
openssl req -x509 -new -key ca.key -sha256 -days 2 -out ca-root.pem \
  -subj "/CN=hello-galaxy-first-bite stand-in authority" \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null

printf 'basicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=clientAuth\n' >client.ext
printf 'basicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth,clientAuth\nsubjectAltName=DNS:localhost,IP:127.0.0.1\n' >server.ext

leaf() { # <file stem> <common name> <extension file>
  openssl ecparam -name prime256v1 -genkey -noout -out "$1-key.pem" 2>/dev/null
  openssl req -new -key "$1-key.pem" -subj "/CN=$2" -out "$1.csr" 2>/dev/null
  openssl x509 -req -in "$1.csr" -CA ca-root.pem -CAkey ca.key -CAcreateserial \
    -sha256 -days 2 -extfile "$3" -out "$1-cert.pem" 2>/dev/null
  chmod 600 "$1-key.pem"
  rm -f "$1.csr"
}
leaf router goat-zenoh-router server.ext
# The router's image reads its key as another user.
chmod 644 router-key.pem
for slot in "$@"; do leaf "$slot" "$slot" client.ext; done
rm -f client.ext server.ext ca-root.srl
echo "minted a root, a router certificate and $# slot certificate(s) in $dir"
