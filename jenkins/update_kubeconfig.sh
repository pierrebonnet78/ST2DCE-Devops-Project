
#!/bin/bash

# Path to the config file
CONFIG_FILE="$HOME/.kube/config"
NEW_CONFIG_FILE="$HOME/.kube/config_jenkins"

# Copy the original config file to a new one
# 
cp "$HOME/.kube/config" "$HOME/.kube/config_jenkins"

# Extract current paths
CERT_AUTH=$(grep "certificate-authority: " $CONFIG_FILE | awk '{print $2}')
CLIENT_CERT=$(grep "client-certificate: " $CONFIG_FILE | awk '{print $2}')
CLIENT_KEY=$(grep "client-key: " $CONFIG_FILE | awk '{print $2}')

# Base64 encode the files
CERT_AUTH_B64=$(cat $CERT_AUTH | base64)
CLIENT_CERT_B64=$(cat $CLIENT_CERT | base64)
CLIENT_KEY_B64=$(cat $CLIENT_KEY | base64)

#Get the IP address of the minikube Docker container
SERVER_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' minikube)
SERVER_URL="https://${SERVER_IP}:8443"

echo "SERVER_URL: $SERVER_URL"

# Replace the paths in the config file with Base64 encoded content
sed -i.bak \
    -e "s|certificate-authority:.*|certificate-authority-data: ${CERT_AUTH_B64}|" \
    -e "s|client-certificate:.*|client-certificate-data: ${CLIENT_CERT_B64}|" \
    -e "s|client-key:.*|client-key-data: ${CLIENT_KEY_B64}|" \
    -e "s|server:.*|server: ${SERVER_URL}|" \
    $NEW_CONFIG_FILE


echo "New config file created successfully at $NEW_CONFIG_FILE."