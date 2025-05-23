#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <peername>"
  exit 1
fi

PEER_NAME="$1"
PEER_DIR="$(dirname "$0")/$PEER_NAME"
SERVER_PUBLIC_KEY="<server_publickey_here>" # <-- Replace with your server's public key
SERVER_ENDPOINT="<server_public_ip_or_dns>:51820" # <-- Replace with your server's endpoint
WG_NETWORK="10.13.13"
PEER_IP_SUFFIX=$(ls $(dirname "$0") | grep -E '^peer[0-9]+$' | sed 's/peer//' | sort -n | tail -n1 | awk '{print $1+1}')
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