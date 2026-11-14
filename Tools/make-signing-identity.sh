#!/bin/bash
# Creates the free, self-signed certificate "ReNotched Self-Signed" in your login keychain. Run it once.
#
# Why: an app that is only signed ad hoc gets a new identity with every build, so macOS treats each update as a
# different app and asks for Bluetooth access (and Full Disk Access for Focus) again. Signed with the same
# certificate every time, the app keeps one identity and its permissions survive updates.
# It does not replace Apple's notarization: Gatekeeper still asks once when the app is opened for the first time.
#
# Usage: ./Tools/make-signing-identity.sh      then ./build.sh signs with it automatically.
set -euo pipefail
NAME="ReNotched Self-Signed"

if security find-identity -p codesigning | grep -q "\"$NAME\""; then
  echo "\"$NAME\" already exists – nothing to do."
  exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT   # the private key only stays in the keychain
cat > "$WORK/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

# valid for 10 years
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$WORK/cert.cnf" \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2> /dev/null
PASS=$(/usr/bin/openssl rand -hex 16)
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -name "$NAME" \
  -out "$WORK/identity.p12" -passout "pass:$PASS"
# -T: codesign may use the key without asking each time
security import "$WORK/identity.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P "$PASS" -T /usr/bin/codesign > /dev/null

echo "Created \"$NAME\" in your login keychain. ./build.sh now signs with it."
echo "Keep it: builds signed with a different certificate count as a different app again."
echo "To back it up, export it from Keychain Access (My Certificates) as a .p12 file."
