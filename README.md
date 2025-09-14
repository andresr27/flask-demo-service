# Demo services

## Flask-demo in python
Very simple hello world python Flask application used for testing monitoring related libraries. At the moments it includes:

    Basic Liveness/Readyness checks
    Structured json logging
    To Do  - Expose metric for Prometheus
    To Do  - Canary deployment with Actions 


### Set the environment

    virtualenv env
    source env/bin/activate
    pip install -r app/requirements.txt
    export AWS_PROFILE="wd_test_devops"
    aws sso login
    source .env

### Run locally
    python main.py
    http://localhost:5000/
    {"event": {"success": false, "message": "invalid access key"}, "level": "error", "ts": "2023-12-08T16:05:50.978294Z"}

### Build image locally
    
    cd app/
    docker build -t ${REGISTRY_URL}/${REPO_NAME}:canary .
    
### Run locally with docker
    docker run  -p 5001:5000  ${REGISTRY_URL}/${REPO_NAME}:canary

[//]: # (TODO: this section needs to be improve with Dev local urls, and proper python metrics enabled)
Getting [http://127.0.0.1:5001/](http://127.0.0.1:5001/) should return a Json with the city flights.
Getting [http://127.0.0.1:5001/readyness](http://127.0.0.1:5001/readyness) should return "UP"


### Deploy demo service to a K8s cluster
Namespace must be created if it doesn't exist, in this case we are deploying demo services to applications ns:
    
    kubectl create ns applications

For Dev login to the Docker-hub registry:
    
    docker login
    
or for prod we are using AWS as an example

    docker login -u AWS -p $(aws ecr get-login-password) ${REGISTRY_URL}

For AWS update secrets in the Kubernetes to be able to pull the new version of the image.   

    kubectl create secret docker-registry ecr \                             
    --docker-server ${REGISTRY_URL} \
    --docker-username=AWS \
    --docker-password=$(aws ecr get-login-password) -n applications

Note: This should be handled by the cluster but sometimes we need to refresh credential periodically to be able to download 
image from the registry.

### Upload image to the registry
 
    docker push ${REGISTRY_URL}/${REPO_NAME}:canary

Deploy the Kubernetes artifacts:

    kubectl apply -f kubernetes/dev/
    
### Test the deployment:

    Getting [http://<cluster-ip>/flask-demo/]() should return a Json with the city flights.
    Getting [http://<cluster-ip>/flask-demo/readyness]() should return "UP"

Try http://minikube-ip/flask-demo/readyness

Of course. Here is a clear summary in English of the key changes to securely manage your API key using a Kubernetes Secret.

### Securing Your API Key

The main goal is to move your sensitive API key out of the `configmap.yaml` file and into a dedicated **Kubernetes Secret**, which is a more secure resource for storing sensitive data like passwords, tokens, and keys.

---

### **1. New Files & Their Purpose**

You will now have **two** separate configuration files instead of one:

| File | Purpose | What goes inside |
| :--- | :--- | :--- |
| **`secret.yaml`** | Stores **sensitive data** (the API key) | Only your encrypted API key |
| **`configmap.yaml`** | Stores **non-sensitive configuration** | URLs, environment names, feature flags |

---

### **2. What Changes in Each File**

**a) The New `secret.yaml` File:**
*   It contains your API key, but the key is **encoded in base64** (which is not encryption, but obfuscation and a requirement for Secrets).
*   You must **encode your actual API key** before putting it in this file.
    ```bash
    echo -n 'eyJ0eXAiOiJKV1QiLCJhbGc...' | base64
    # This command will output a long encoded string
    ```
*   The file looks like this, please do not commit:
    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: demo-service-secrets
      
    type: Opaque
    data:
      api_key: ZXlKMGVYQWlnBZWFFpT2pF... # (your encoded key goes here)
    ```
    
For Production, we want to set this on deployment script: cli.sh

**b) The Updated `configmap.yaml` File:**
*   The API key is **removed** from this file. It now only contains safe, non-secret settings.
    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: flask-demo-config
      
    data:
      api_base_url: <API_BASE_URL>
    ```

**c) The Updated `deployment.yaml` File:**
*   The container's environment variables now pull from the **correct source**:
    *   `FLIGHTS_API_KEY` now comes from the **Secret** (`secretKeyRef`).
    *   `IMAGE_URL` and `API_BASE_URL` still come from the **ConfigMap** (`configMapKeyRef`).

    ```yaml
    env:
    - name: API_KEY
      valueFrom:
        secretKeyRef:           # <-- CHANGED to secretKeyRef
          name: demo-service-secrets
          key: flights_api_key
    - name: API_URL
      valueFrom:
        configMapKeyRef:       
          name: flask-demo-config
          key: api_base_url
    ```

---

### **3. How to Apply the Changes to Your Cluster**

You must create the resources in the correct order:

1.  **Apply the ConfigMap:**
    ```bash
    kubectl apply -f configmap.yaml
    ```
2.  **Apply the Secret:**
    ```bash
    kubectl apply -f secret.yaml
    ```
3.  **Apply/Update the Deployment:**
    ```bash
    kubectl apply -f deployment-canary.yaml
    kubectl apply -f deployment.yaml
    ```
---

### **3. Using cli.sh script to deploy change to your cluster**

### **4. Python Script for Advanced Canary Analysis**

For more sophisticated canary analysis, create a Python script to automate validation:

**canary-validation.py**:
```python
#!/usr/bin/env python3

import requests
import json
import os
import time
import sys
from kubernetes import client, config

def validate_canary():
    # Load Kubernetes config
    try:
        config.load_incluster_config()  # When running inside cluster
    except:
        config.load_kube_config()  # When running locally
    
    v1 = client.CoreV1Api()
    
    # Get canary pods
    canary_pods = v1.list_namespaced_pod(
        namespace=os.getenv('K8S_NAMESPACE', 'default'),
        label_selector="track=canary"
    )
    
    if not canary_pods.items:
        print("No canary pods found!")
        return False
    
    # Test each canary pod
    success_count = 0
    for pod in canary_pods.items:
        pod_name = pod.metadata.name
        print(f"Testing canary pod: {pod_name}")
        
        try:
            # Execute health check inside the pod
            resp = requests.get(f"http://{pod.status.pod_ip}:8080/health", timeout=5)
            if resp.status_code == 200:
                print(f"✓ Pod {pod_name} health check passed")
                success_count += 1
            else:
                print(f"✗ Pod {pod_name} health check failed: HTTP {resp.status_code}")
        except Exception as e:
            print(f"✗ Pod {pod_name} health check error: {str(e)}")
    
    # Determine if canary is successful
    success_rate = success_count / len(canary_pods.items) if canary_pods.items else 0
    print(f"Canary success rate: {success_rate:.2%}")
    
    return success_rate >= 0.8  # Require 80% success rate

if __name__ == "__main__":
    # Wait a bit for pods to stabilize
    time.sleep(30)
    
    # Run validation
    if validate_canary():
        print("Canary validation passed!")
        sys.exit(0)
    else:
        print("Canary validation failed!")
        sys.exit(1)
```

### **Key Features**

*   **Separation of Concerns:** Configuration and secrets are managed separately.
*   **Security:** Secrets are more secure than ConfigMaps. Access to them can be controlled more strictly using Kubernetes **RBAC** (Role-Based Access Control).
*   **Best Practice:** This is the standard and correct way to handle sensitive information in Kubernetes, which is especially important for a DevOps Lead role.

This approach ensures your API key is handled securely according to Kubernetes best practices.