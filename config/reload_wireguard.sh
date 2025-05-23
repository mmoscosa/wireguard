#!/bin/bash
set -e

SERVICE="wireguard"

# Find the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."

cd "$PROJECT_ROOT"
echo "Restarting WireGuard container via docker-compose..."
docker-compose restart $SERVICE
echo "Done." 