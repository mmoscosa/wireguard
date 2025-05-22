#!/bin/bash

set -e

# 1. Start the WireGuard server
echo "Starting WireGuard server with Docker Compose..."
docker-compose up -d

# 2. Wait for the client config to be generated
echo "Waiting for client config to be generated..."
CONFIG_FILE=./config/peer1/peer1.conf
for i in {1..10}; do
    if [ -f "$CONFIG_FILE" ]; then
        break
    fi
    sleep 2
done

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Client config not found at $CONFIG_FILE. Exiting."
    exit 1
fi

# 3. Adjust the client config to use 127.0.0.1 for local testing
echo "Adjusting client config to use 127.0.0.1 for local testing..."
cp "$CONFIG_FILE" ./peer1_local.conf
sed -i.bak 's/^Endpoint = .*/Endpoint = 127.0.0.1:51820/' ./peer1_local.conf
rm ./peer1_local.conf.bak

# 4. Bring up the WireGuard interface
echo "Bringing up the WireGuard interface..."
sudo wg-quick up ./peer1_local.conf

# 5. Show WireGuard status
echo "WireGuard status:"
sudo wg

echo "Test complete. To bring down the interface, run:"
echo "  sudo wg-quick down ./peer1_local.conf"
