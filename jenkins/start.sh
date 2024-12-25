#!/bin/bash

# Start the Docker daemon with debug logging
sudo dockerd --debug &

echo "Docker daemon started successfully!"

# Create directory with proper permissions
mkdir -p /var/jenkins_home/plugin_manager
cd /var/jenkins_home/plugin_manager

# Download and set permissions for Jenkins Plugin Manager
wget https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.12.13/jenkins-plugin-manager-2.12.13.jar
chown -R jenkins:jenkins /var/jenkins_home/plugin_manager
chmod +x jenkins-plugin-manager-2.12.13.jar

# Install plugins as jenkins user
java -jar /var/jenkins_home/plugin_manager/jenkins-plugin-manager-2.12.13.jar --plugin-download-directory /var/jenkins_home/plugins --plugins workflow-aggregator github-branch-source git docker-plugin job-dsl docker-workflow credentials-binding timestamper ws-cleanup kubernetes

exec /usr/local/bin/jenkins.sh