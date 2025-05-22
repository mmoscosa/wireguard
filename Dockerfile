# Use the official linuxserver/wireguard image
FROM linuxserver/wireguard:latest

# No additional setup needed; configuration will be mounted at runtime
# See docker-compose.yml for volume and environment setup 