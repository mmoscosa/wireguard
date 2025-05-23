#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <peername>"
  exit 1
fi

# Get the absolute path to the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PEER_NAME="$1"
PEER_DIR="$SCRIPT_DIR/$PEER_NAME"
# Read server public key from file
SERVER_PUBLIC_KEY=$(cat "$SCRIPT_DIR/server/publickey-server")
SERVER_ENDPOINT="52.72.186.43:51820"
WG_NETWORK="10.13.13"
PEER_IP_SUFFIX=$(ls "$SCRIPT_DIR" | grep -E '^peer[0-9]+$' | sed 's/peer//' | sort -n | tail -n1 | awk '{print $1+1}')
if [ -z "$PEER_IP_SUFFIX" ]; then PEER_IP_SUFFIX=2; fi
PEER_IP="$WG_NETWORK.$PEER_IP_SUFFIX/32"

mkdir -p "$PEER_DIR"
cd "$PEER_DIR"

umask 077
wg genkey | tee privatekey-$PEER_NAME | wg pubkey > publickey-$PEER_NAME
wg genpsk > presharedkey-$PEER_NAME

PRIV_KEY=$(cat privatekey-$PEER_NAME)
PUB_KEY=$(cat publickey-$PEER_NAME)
PSK=$(cat presharedkey-$PEER_NAME)

cat > $PEER_NAME.conf <<EOF
[Interface]
PrivateKey = $PRIV_KEY
Address = $PEER_IP

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $PSK
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

# Also create <peername>_local.conf with the improved local config format
cat > ${PEER_NAME}_local.conf <<EOF
[Interface]
PrivateKey = $PRIV_KEY
ListenPort = 51820
Address = $PEER_IP
DNS = 1.1.1.1
MTU = 1280

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $PSK
AllowedIPs = 10.13.13.0/24
Endpoint = $SERVER_ENDPOINT
PersistentKeepalive = 25
EOF

if command -v qrencode >/dev/null 2>&1; then
  qrencode -t ansiutf8 < $PEER_NAME.conf > $PEER_NAME.png
  echo "QR code generated: $PEER_NAME/$PEER_NAME.png"
fi

echo
echo "Add the following to your server's wg0.conf:"
echo
echo "[Peer]"
echo "# $PEER_NAME"
echo "PublicKey = $PUB_KEY"
echo "PresharedKey = $PSK"
echo "AllowedIPs = $PEER_IP"
echo
echo "Peer config created at: $PEER_DIR/$PEER_NAME.conf" 