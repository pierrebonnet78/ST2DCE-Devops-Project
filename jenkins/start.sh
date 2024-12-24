#!/bin/bash

# Start the Docker daemon with debug logging
sudo dockerd --debug &

echo "Docker daemon started successfully!"

# Start Jenkins
exec /usr/local/bin/jenkins.sh