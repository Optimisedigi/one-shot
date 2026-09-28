#!/usr/bin/env bash
set -euo pipefail

IDENTITY_NAME="${ONESHOT_CODESIGN_IDENTITY:-One Shot Local Development}"
KEYCHAIN="${ONESHOT_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"

if security find-identity -v -p codesigning "$KEYCHAIN" | grep -Fq "\"$IDENTITY_NAME\""; then
    echo "Using existing code signing identity: $IDENTITY_NAME"
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/openssl.cnf" <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = codesign_ext

[ dn ]
CN = $IDENTITY_NAME
O = One Shot

[ codesign_ext ]
basicConstraints = critical,CA:true
keyUsage = critical,digitalSignature,keyCertSign
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
EOF

openssl req \
    -new \
    -newkey rsa:2048 \
    -nodes \
    -x509 \
    -days 3650 \
    -config "$TMP_DIR/openssl.cnf" \
    -keyout "$TMP_DIR/oneshot-dev.key" \
    -out "$TMP_DIR/oneshot-dev.crt" \
    >/dev/null 2>&1

P12_PASSWORD="oneshot-local-dev"

openssl pkcs12 \
    -export \
    -legacy \
    -macalg sha1 \
    -keypbe PBE-SHA1-3DES \
    -certpbe PBE-SHA1-3DES \
    -name "$IDENTITY_NAME" \
    -inkey "$TMP_DIR/oneshot-dev.key" \
    -in "$TMP_DIR/oneshot-dev.crt" \
    -out "$TMP_DIR/oneshot-dev.p12" \
    -passout pass:"$P12_PASSWORD" \
    >/dev/null 2>&1

security import "$TMP_DIR/oneshot-dev.p12" \
    -k "$KEYCHAIN" \
    -P "$P12_PASSWORD" \
    -T /usr/bin/codesign \
    >/dev/null

security add-trusted-cert \
    -d \
    -r trustRoot \
    -p codeSign \
    -k "$KEYCHAIN" \
    "$TMP_DIR/oneshot-dev.crt" \
    >/dev/null

echo "Created code signing identity: $IDENTITY_NAME"
