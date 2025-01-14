pipeline {
    agent {
        kubernetes {
            defaultContainer 'kaniko'
            yaml """
apiVersion: v1
kind: Pod
metadata:
  name: kaniko
spec:
  containers:
    - name: git
      image: alpine/git
      command:
        - /bin/cat
      tty: true
      volumeMounts:
        - name: shared-workspace
          mountPath: /workspace
    - name: kaniko
      image: gcr.io/kaniko-project/executor:debug
      command:
        - /busybox/cat
      tty: true
      volumeMounts:
        - name: shared-workspace
          mountPath: /workspace
      resources:
        requests:
          memory: "1.5Gi"
          cpu: "1"
        limits:
          memory: "2Gi"
          cpu: "2"
    - name: deployer
      image: dtzar/helm-kubectl:latest
      command:
        - /bin/cat
      tty: true
      volumeMounts:
        - name: shared-workspace
          mountPath: /workspace
      resources:
        requests:
          memory: "1.5Gi"
          cpu: "1"   
        limits:
          memory: "2Gi"
          cpu: "2"
  volumes:
    - name: shared-workspace
      emptyDir: {}
"""
        }
    }

    stages {
        stage('Checkout') {
            steps {
                container('git') {
                    sh '''
                    rm -rf /workspace/* || true
                    git clone https://github.com/pierrebonnet78/ST2DCE-Devops-Project.git /workspace/project
                    '''
                }
            }
        }
 
        stage('Get Minikube Registry IP Address') {
            steps {
                container('deployer') {
                    script {
                        withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                            sh '''
                            
                            # Create .kube directory with proper permissions
                            mkdir -p /root/.kube
                            chmod 700 /root/.kube
                            
                            # Try copying with verbose output
                            cp -v "$KUBECONFIG" /root/.kube/config || echo "Copy failed with status: $?"
                            
                            # Check if the copy succeeded
                            ls -la /root/.kube/config || echo "Config file not created"
                            
                            REGISTRY_IP=$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.clusterIP}')
                            echo "REGISTRY_IP=$REGISTRY_IP" > /workspace/registry.env
                            
                            '''
                        }
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                container('kaniko') {
                    sh '''
                    source /workspace/registry.env
                    echo "Building image and pushing to $REGISTRY_IP:80"
                    
                    /kaniko/executor \
                        --dockerfile=/workspace/project/Dockerfile \
                        --context=/workspace/project \
                        --destination=$REGISTRY_IP:80/go-app:${BUILD_NUMBER} \
                        --insecure \
                    '''
                }
            }
        }

        stage('Deploy to Development') {
            steps {
                container('deployer') {
                    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                        sh '''
                        source /workspace/registry.env
                        
                        # Create development namespace if it doesn't exist
                        kubectl create namespace development --dry-run=client -o yaml | kubectl apply -f -
                        
                        
                        # Replace image and namespace in deployment file
                        sed -i "s|image: .*|image: $REGISTRY_IP:80/go-app:${BUILD_NUMBER}|g" /workspace/project/deployment/k8s_deployment_dev.yaml
                        
                        # Apply the deployment to development namespace
                        kubectl apply -f /workspace/project/deployment/k8s_deployment_dev.yaml -n development
                        
                        # Wait for deployment with timeout
                        timeout 300s kubectl rollout status deployment/go-app-deployment -n development || exit 1
                        
                        # Show deployment status
                        echo "Development deployment status:"
                        kubectl get deployments,pods,services -n development
                        '''
                    }
                }
            }
        }

        stage('Test Application Endpoint') {
            steps {
                container('deployer') {
                    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                        sh '''
                        # Wait for service to get an IP and endpoints to be ready
                        echo "Waiting for service to be ready..."
                
                # Wait for endpoints to be ready (max 60 seconds)
                for i in $(seq 1 30); do
                    if kubectl get endpoints go-app-service -n development -o jsonpath='{.subsets[0].addresses[0].ip}' > /dev/null 2>&1; then
                        echo "Service endpoints are ready!"
                        break
                        fi
                        echo "Waiting for service endpoints... (Attempt $i/30)"
                        sleep 2
                        if [ $i -eq 30 ]; then
                            echo "Timeout waiting for service endpoints"
                            exit 1
                        fi
                        done
                        
                        # Get service URL
                        SERVICE_IP=$(kubectl get svc go-app-service -n development -o jsonpath='{.spec.clusterIP}')
                        SERVICE_PORT=$(kubectl get svc go-app-service -n development -o jsonpath='{.spec.ports[0].port}')
                        SERVICE_URL="http://${SERVICE_IP}:${SERVICE_PORT}"
                        
                        echo "Testing service at ${SERVICE_URL}"
                        
                        # Test the endpoint
                        response=$(curl -s -o /dev/null -w "%{http_code}" ${SERVICE_URL}/whoami)
                        
                        if [ "$response" = "200" ]; then
                            echo "Test passed! Service returned 200"
                        else
                            echo "Test failed! Service returned $response"
                            exit 1
                        fi
                        '''
                    }
                }
            }
        }

        stage('Deploy to Production') {
            steps {
                container('deployer') {
                    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                        sh '''
                        source /workspace/registry.env
                        
                        # Create production namespace if it doesn't exist
                        kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
                        
                        # Replace image and namespace in deployment file
                        sed -i "s|image: .*|image: $REGISTRY_IP:80/go-app:${BUILD_NUMBER}|g" /workspace/project/deployment/k8s_deployment_prod.yaml
                        
                        # Apply the deployment to production namespace
                        kubectl apply -f /workspace/project/deployment/k8s_deployment_prod.yaml -n production
                        
                        # Wait for deployment with timeout
                        timeout 300s kubectl rollout status deployment/go-app-deployment -n production || exit 1
                        
                        # Show deployment status
                        echo "Production deployment status:"
                        kubectl get deployments,pods,services -n production
                        '''
                    }
                }
            }
        }

        stage('Install Monitoring Stack') {
    steps {
        container('deployer') {
            withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                sh '''
                # Create monitoring namespace
                kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

                # Add Helm repositories
                helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
                helm repo add grafana https://grafana.github.io/helm-charts
                helm repo update

                helm upgrade --install prometheus-operator prometheus-community/kube-prometheus-stack \
                    --set defaultRules.create=false \
                    --namespace monitoring \
                    --set prometheusOperator.admissionWebhooks.enabled=true \
                    --set prometheusOperator.createCustomResource=false \
                    --set grafana.enabled=true \
                    --set grafana.adminPassword=admin \
                    --set alertmanager.enabled=true \
                    --set prometheus.enabled=true \
                    --wait

                # Wait for Prometheus Operator to be ready
                echo "Waiting for Prometheus Operator pods to be ready..."
                kubectl wait --for=condition=available deployment.apps/prometheus-operator-kube-p-operator -n monitoring --timeout=300s


                # Apply PrometheusRules from external file
                kubectl apply -f /workspace/project/monitoring/prometheus-alerts.yaml

                # Apply AlertManager config
                kubectl apply -f /workspace/project/monitoring/alertmanager-config.yaml

                # Verify Prometheus rules are loaded
                echo "Waiting for Prometheus to be ready..."
                sleep 10

                PROMETHEUS_POD=$(kubectl get pods -n monitoring -l "app.kubernetes.io/name=prometheus,prometheus=prometheus-operator-kube-p-prometheus" -o jsonpath="{.items[0].metadata.name}")
                if [ -z "$PROMETHEUS_POD" ]; then
                    echo "No Prometheus pod found. Checking all pods in monitoring namespace:"
                    kubectl get pods -n monitoring --show-labels
                    exit 1
                fi


                echo "Checking configured rules..."
                kubectl exec -n monitoring $PROMETHEUS_POD -c prometheus -- wget -qO- http://localhost:9090/api/v1/rules || true
                

                # Install Loki Stack
                helm upgrade --install loki grafana/loki-stack \
                    --namespace monitoring \
                    --set grafana.enabled=false \
                    --set promtail.enabled=true \
                    --set loki.persistence.enabled=true \
                    --set loki.persistence.size=10Gi \
                    --set loki.config.limits_config.enforce_metric_name=false \
                    --set loki.config.limits_config.reject_old_samples=true \
                    --set loki.config.limits_config.reject_old_samples_max_age=168h \
                    --set loki.config.chunk_store_config.max_look_back_period=168h \
                    --set loki.config.table_manager.retention_deletes_enabled=true \
                    --set loki.config.table_manager.retention_period=168h \
                    --set loki.resources.requests.cpu=200m \
                    --set loki.resources.requests.memory=256Mi \
                    --set loki.resources.limits.cpu=1000m \
                    --set loki.resources.limits.memory=1Gi \
                    --set promtail.resources.requests.cpu=100m \
                    --set promtail.resources.requests.memory=128Mi \
                    --set promtail.resources.limits.cpu=200m \
                    --set promtail.resources.limits.memory=256Mi \
                    --timeout 15m \
                    --wait \
                    --atomic

                # Wait for Loki Stack deployment
                kubectl rollout status statefulset/loki -n monitoring
                '''
            }
        }
    }
}


        stage('Configure Grafana Dashboard and Datasources') {
            steps {
                container('deployer') {
                    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                        sh '''
                        # Wait for Grafana to be ready
                        kubectl rollout status deployment/prometheus-operator-grafana -n monitoring
                        
                        # Get Grafana pod name
                        GRAFANA_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
                        
                        # Check if Loki datasource exists and get its UID
                        echo "Checking for existing Loki datasource..."
                        EXISTING_DS=$(kubectl exec -n monitoring $GRAFANA_POD -- curl -s \
                            http://admin:admin@localhost:3000/api/datasources/name/Loki)
                        
                        if echo "$EXISTING_DS" | grep -q "id"; then
                            echo "Loki datasource exists, updating..."
                            DS_ID=$(echo "$EXISTING_DS" | grep -o '"id":[0-9]*' | cut -d':' -f2)
                            LOKI_RESPONSE=$(kubectl exec -n monitoring $GRAFANA_POD -- curl -s -X PUT \
                                -H "Content-Type: application/json" \
                                -d '{
                                    "name": "Loki",
                                    "type": "loki",
                                    "url": "http://loki:3100",
                                    "access": "proxy",
                                    "basicAuth": false,
                                    "isDefault": false
                                }' \
                                "http://admin:admin@localhost:3000/api/datasources/$DS_ID")
                        else
                            echo "Creating new Loki datasource..."
                            LOKI_RESPONSE=$(kubectl exec -n monitoring $GRAFANA_POD -- curl -s -X POST \
                                -H "Content-Type: application/json" \
                                -d '{
                                    "name": "Loki",
                                    "type": "loki",
                                    "url": "http://loki:3100",
                                    "access": "proxy",
                                    "basicAuth": false,
                                    "isDefault": false
                                }' \
                                http://admin:admin@localhost:3000/api/datasources)
                        fi
                        
                        # Extract UID from response or get it from existing datasource
                        LOKI_UID=$(echo "$EXISTING_DS" | grep -o '"uid":"[^"]*"' | cut -d'"' -f4)
                        if [ -z "$LOKI_UID" ]; then
                            LOKI_UID=$(echo "$LOKI_RESPONSE" | grep -o '"uid":"[^"]*"' | cut -d'"' -f4)
                        fi
                        
                        echo "Using Loki datasource UID: $LOKI_UID"
                        
                        # Create dashboard
                        echo "Creating dashboard..."
                        
                        kubectl exec -n monitoring $GRAFANA_POD -- curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{
        "dashboard": {
            "uid": null,
            "title": "Production Errors",
            "tags": ["logs", "production"],
            "timezone": "browser",
            "schemaVersion": 16,
            "version": 0,
            "refresh": "5s",
            "time": {
                "from": "now-1h",
                "to": "now"
            },
            "panels": [
                {
                    "id": 1,
                    "title": "Error Logs in Production",
                    "type": "logs",
                    "datasource": {
                        "type": "loki",
                        "uid": "'${LOKI_UID}'"
                    },
                    "gridPos": {
                        "h": 8,
                        "w": 24,
                        "x": 0,
                        "y": 0
                    },
                    "targets": [
                        {
                            "refId": "A",
                            "expr": "{namespace=\\"production\\"} |= \\"error\\"",
                            "datasource": {
                                "type": "loki",
                                "uid": "'${LOKI_UID}'"
                            }
                        }
                    ]
                }
            ]
        },
        "overwrite": true
    }' \
    http://admin:admin@localhost:3000/api/dashboards/db



                        echo "Configuration completed successfully"
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo """
            Pipeline completed successfully!
            
            To access Grafana:
            1. Run: kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80
            2. Visit: http://localhost:3000
            3. Login with:
               Username: admin
               Password: admin

            To access AlertManager:
            1. Run: kubectl port-forward -n monitoring svc/prometheus-operator-kube-p-alertmanager 9093:9093
            2. Visit: http://localhost:9093

            To access Prometheus:
            1. Run: kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
            2. Visit: http://localhost:9090

            To access the Go Application in production:
            1. Run: kubectl port-forward svc/go-app-service -n production 8081:8080
            2. Visit: http://localhost:8081

            To access the Go Application in development:
            1. Run: kubectl port-forward svc/go-app-service -n development 8082:8080
            2. Visit: http://localhost:8082

            To triggered an alert that will be sent to the email address configured in the AlertManager config:
            1. cd into the monitoring/testing-pods directory
            2. Run: kubectl apply -f test-error-logger.yaml

            To triggered an error that will be logged in the Grafana dashboard:
            1. cd into the monitoring/testing-pods directory
            2. Run: kubectl apply -f test-error-logger.yaml
            or 
            1. Access the go application in production
            2. Navigate to the /generate-error endpoint

            3. Access the Grafana dashboard and navigate to the "Production Errors" dashboard
            """
        }
    }
}