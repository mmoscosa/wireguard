#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <peername> [split|sql]"
  echo "  <peername>: Name of the peer (required)"
  echo "  [split]: Optional. Use 'split' for split tunnel (only VPN subnet)."
  echo "  [sql]: Optional. Use 'sql' to only route traffic to 10.13.13.1 (e.g., for PostgreSQL)."
  echo "  Default is full tunnel (all traffic)."
  exit 1
fi

# Get the absolute path to the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PEER_NAME="$1"
TUNNEL_TYPE="${2:-full}"
PEER_DIR="$SCRIPT_DIR/$PEER_NAME"
# Read server public key from file
SERVER_PUBLIC_KEY=$(cat "$SCRIPT_DIR/server/publickey-server")
SERVER_ENDPOINT="52.72.186.43:51820"
WG_NETWORK="10.13.13"
PEER_IP_SUFFIX=$(ls "$SCRIPT_DIR" | grep -E '^peer[0-9]+$' | sed 's/peer//' | sort -n | tail -n1 | awk '{print $1+1}')
if [ -z "$PEER_IP_SUFFIX" ]; then PEER_IP_SUFFIX=2; fi
PEER_IP="$WG_NETWORK.$PEER_IP_SUFFIX/32"

# Set AllowedIPs based on tunnel type
if [ "$TUNNEL_TYPE" = "split" ]; then
  ALLOWED_IPS="10.13.13.0/24"
elif [ "$TUNNEL_TYPE" = "sql" ]; then
  ALLOWED_IPS="10.13.13.1/32"
else
  ALLOWED_IPS="0.0.0.0/0, ::/0"
fi

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
# This peer's private key
PrivateKey = $PRIV_KEY
Address = $PEER_IP

[Peer]
# This is the SERVER'S public key!
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $PSK
Endpoint = $SERVER_ENDPOINT
AllowedIPs = $ALLOWED_IPS
PersistentKeepalive = 25
EOF

# Also create <peername>_local.conf with the improved local config format
cat > ${PEER_NAME}_local.conf <<EOF
[Interface]
# This peer's private key
PrivateKey = $PRIV_KEY
ListenPort = 51820
Address = $PEER_IP
DNS = 1.1.1.1
MTU = 1280

[Peer]
# This is the SERVER'S public key!
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $PSK
# If you want to only route PostgreSQL (port 5432) traffic, use a client-side firewall to restrict traffic to 10.13.13.1:5432
AllowedIPs = $ALLOWED_IPS
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
echo "Peer config created at: $PEER_DIR/$PEER_NAME.conf (full tunnel by default)"
echo "  Use the 'split' option for split tunnel (VPN subnet only)."
echo "  Use the 'sql' option to only route traffic to 10.13.13.1 (e.g., for PostgreSQL)." 