#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# CONFIGURATION (you will be prompted, defaults provided)
###############################################################################

read -rp "Enter Common Name (FQDN or IP) [glpi.local]: " CN
CN=${CN:-glpi.local}

read -rp "Enter SANs (comma-separated DNS/IP) [glpi.local,127.0.0.1]: " SANS
SANS=${SANS:-glpi.local,127.0.0.1}

CERT_DIR="/etc/ssl/certs"
KEY_DIR="/etc/ssl/private"
CERT_NAME="glpi-selfsigned"

CERT_FILE="${CERT_DIR}/${CERT_NAME}.crt"
KEY_FILE="${KEY_DIR}/${CERT_NAME}.key"
OPENSSL_CNF="/tmp/${CERT_NAME}-openssl.cnf"

###############################################################################
# CHECK ROOT
###############################################################################

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

###############################################################################
# BUILD SAN CONFIG
###############################################################################

IFS=',' read -ra SAN_ARRAY <<< "$SANS"

SAN_CONFIG=""
i=1
for san in "${SAN_ARRAY[@]}"; do
  san=$(echo "$san" | xargs)
  if [[ "$san" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    SAN_CONFIG+="IP.${i} = ${san}\n"
  else
    SAN_CONFIG+="DNS.${i} = ${san}\n"
  fi
  ((i++))
done

###############################################################################
# CREATE OPENSSL CONFIG WITH SAN
###############################################################################

cat <<EOF > "$OPENSSL_CNF"
[ req ]
default_bits       = 4096
default_md         = sha256
prompt             = no
distinguished_name = dn
x509_extensions    = v3_req

[ dn ]
CN = ${CN}

[ v3_req ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
$(echo -e "$SAN_CONFIG")
EOF

###############################################################################
# GENERATE KEY + CERT (10 YEARS, SHA-256)
###############################################################################

echo "Generating private key and self-signed certificate (SHA-256, 10 years)..."

openssl req -x509 \
  -nodes \
  -days 3650 \
  -newkey rsa:4096 \
  -keyout "$KEY_FILE" \
  -out "$CERT_FILE" \
  -config "$OPENSSL_CNF"

###############################################################################
# SECURE PERMISSIONS
###############################################################################

chmod 600 "$KEY_FILE"
chmod 644 "$CERT_FILE"

###############################################################################
# CLEANUP
###############################################################################

rm -f "$OPENSSL_CNF"

###############################################################################
# DONE
###############################################################################

echo
echo "Certificate generated successfully:"
echo "  Certificate: $CERT_FILE"
echo "  Private Key: $KEY_FILE"
echo
echo "Hash algorithm : SHA-256"
echo "Key size       : RSA 4096"
echo "Validity       : 10 years"
echo
echo "You can now reference these files in Apache:"
echo "  SSLCertificateFile    $CERT_FILE"
echo "  SSLCertificateKeyFile $KEY_FILE"
