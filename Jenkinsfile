pipeline {
    agent any

    environment {
        IMAGE_NAME = "go-app:latest"
        CONTAINER_NAME = "go-app-container"
    }

    stages {
        stage('Checkout') {
            steps {
                branch 'main',
                git 'https://github.com/pierrebonnet78/ST2DCE-Devops-Project.git'
            }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    sh 'docker build -t ${IMAGE_NAME} .'
                }
            }
        }
        stage('Run Docker Container') {
            steps {
                script {
                    // Stop and remove the container if it's already running
                    sh 'docker rm -f ${CONTAINER_NAME} || true'
                    
                    // Run the container
                    sh '''
                    docker run -d --name ${CONTAINER_NAME} -p 8081:8080 ${IMAGE_NAME}
                    '''
                }
            }
        }
        stage('Test Application') {
            steps {
                script {
                    // Wait for the container to start
                    sh 'sleep 10'

                    // Perform a test request
                    sh 'curl -f http://localhost:8081/whoami'
                }
            }
        }
    }

    post {
        always {
            echo 'Cleaning up...'
            sh 'docker rm -f ${CONTAINER_NAME} || true'
        }
    }
}
