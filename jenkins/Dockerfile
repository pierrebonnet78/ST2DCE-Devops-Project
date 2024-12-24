FROM jenkins/jenkins:lts-jdk17

USER root

# Install necessary packages
RUN apt-get update && \
    apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    sudo

# Add Docker's official GPG key
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
RUN echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
RUN apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add jenkins user to docker group
RUN usermod -aG docker jenkins

# Configure sudo for jenkins user
RUN echo "jenkins ALL=(ALL) NOPASSWD: /usr/bin/dockerd" >> /etc/sudoers

# Create start-up script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Switch back to jenkins user
USER jenkins

# Jenkins port
EXPOSE 8080

# Docker daemon port
EXPOSE 2376

ENTRYPOINT ["/start.sh"]