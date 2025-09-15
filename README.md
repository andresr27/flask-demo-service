# Demo services (Work in progress...)

## Flask-demo in python
Very simple hello world python Flask application used for testing monitoring related libraries. 
At the moments it includes:

- Basic Liveness/Readyness checks 
- Structured json logging 
- Expose Python metric for Prometheus - To Do
- Canary deployment with GH Actions - To Do
- Validate metrics with Zabbix - To Do
- Send logs to Opensearch - To Do
- Prod environment in EKS - To Do



### Set the environment for local development

    virtualenv env
    source env/bin/activate
    pip install -r app/requirements.txt


### Run locally
    python main.py
    {"event": {"success": false, "message": "invalid access key"}, "level": "error", "ts": "2023-12-08T16:05:50.978294Z"}

  - Getting [http://127.0.0.1:5000/](http://127.0.0.1:5001/) should return a Json with flights if api key is working. 
  - Getting [http://127.0.0.1:5000/readyness](http://127.0.0.1:5001/readyness) should return "UP". Improve with actuators.

### Build and Tag image locally
    
    cd app/
    docker build -t ${IMAGE_URL}/${DEPLOY_VERSION}-canary .
    
### Run locally with Docker
    docker run  -p 5001:5000  ${IMAGE_URL}/${DEPLOY_VERSION}-canary

[//]: # (TODO: this section needs to be improve with Dev local urls, and proper python metrics enabled)
- Getting [http://127.0.0.1:5001/](http://127.0.0.1:5001/) should return a Json with flights if api key is working. 
- Getting [http://127.0.0.1:5001/readyness](http://127.0.0.1:5001/readyness) should return "UP". Improve with actuators.


### Deploy demo service to Dev

Start kubernetes cluster using Docker-desktop UI or using Minikube with:

    minikube start
Or set up your local kubectl context:
    
    kubectl config use-context minikube


Get pods running in the applications namespace.

    kubectl get pods -n applications

For Dev login to the Docker-hub registry and push image to the repository:
    
    docker login
    docker push 

### Deploy to AWS production cluster

Login to AWS:

    export AWS_PROFILE="admin_stage_devops"
    aws sso login
    source .env    
    docker login -u AWS -p $(aws ecr get-login-password) ${REGISTRY_URL}

For AWS update secrets in the Kubernetes to be able to pull the new version of the image.   

    kubectl create secret docker-registry ecr \                             
    --docker-server ${REGISTRY_URL} \
    --docker-username=AWS \
    --docker-password=$(aws ecr get-login-password) -n applications

Note: This should be handled by the cluste, but sometimes we need to refresh credential periodically to be able to download 
image from the registry.

### Upload image to the registry
 
    docker push ${REGISTRY_URL}/${REPO_NAME}:canary

Deploy the Kubernetes artifacts:

    kubectl apply -f kubernetes/prod/
    
### Test the deployment:

    Getting [http://<cluster-ip>/flask-demo/]() should return a Json with flights codes.
    Getting [http://<cluster-ip>/flask-demo/readyness]() should return "UP"

Try http://minikube-ip/flask-demo/readyness


### Securing Your API Key

The main goal is to move your sensitive API key out of the `configmap.yaml` file and into a dedicated **Kubernetes Secret**, which is a more secure resource for storing sensitive data like passwords, tokens, and keys.


| File | Purpose | What goes inside |
| :--- | :--- | :--- |
| **`secret.yaml`** | Stores **sensitive data** (the API key) | Only your encrypted API key |
| **`configmap.yaml`** | Stores **non-sensitive configuration** | URLs, environment names, feature flags |


**a) The`secret.yaml` File:**
*   It contains your API key, but the key is **encoded in base64** (which is not encryption, but obfuscation and a requirement for Secrets).
*   You must **encode your actual API key** before putting it in this file.
    ```bash
    echo -n 'eyJ0eXAiOiJKV1QiLCJhbGc...' | base64
    # This command will output a long encoded string
    ```
*   the kubernetes config:
    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: demo-service-secrets
      
    type: Opaque
    data:
      api_key: ZXlKMGVYQWlnBZWFFpT2pF... # (your encoded key goes here)
    ```
    
For Production, we want to set this on deployment retrieving the key from a dedicated like AWS secrets or Vault.

**b) The Updated `configmap.yaml` File:**
*   The API key is **removed** from this file. It now only contains safe, non-secret settings.
    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: flask-demo-config
      
    data:
      api_base_url: <API_BASE _URL>
    ```

**c) The Updated `deployment.yaml` File:**
*   The container's environment variables now pull from the **correct source**:
    *   `API_KEY` now comes from the **Secret** (`secretKeyRef`).
    *   `API_URL` still come from the **ConfigMap** (`configMapKeyRef`).

    ```yaml
    env:
    - name: API_KEY
      valueFrom:
        secretKeyRef:           
          name: demo-service-secrets
          key: api_key
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
    kubens applications 
    kubectl apply -f configmap.yaml
    ```
2.  **Apply the Secret:**
    ```bash
    kubectl apply -f secret.yaml
    ```
3.  **Update image version**
    ```bash
    kubectl set image deployment demo-service-canary demo-service="${IMAGE_URL}":"${DEPLOY_VERSION}"
    ```

4.  **Apply/Update the Deployment:**
    ```bash
    kubectl rollout restart deployment-canary.yaml
    # Once canary is validated
    kubectl rollout restart -f deployment.yaml
    ```
---

### **3. Using deploy.sh script to deploy change to your cluster**}
```bash
Usage: ./deploy.sh [test | up | down | post]
    test   : runs the full test suite within the test environment
    up     : brings up a clean test environment
    down   : brings down the test environment
    post   : runs the post build steps
    deploy <environment> : runs the deployment steps on the give environment
```



### **4. Python Script for Advanced Canary Analysis**

For more sophisticated canary analysis we can create a Python script to automate validation and a monitoring agent that 
we run on schedule to validate endpoints and current deployment status, check this project for more [synthetic-checker.](https://github.com/andresr27/devops_kubernetes_sample/tree/latest_branch/middleware/prod/kubernetes/synthetic-checker)

```python
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

```

### **Key Features**


*   **Security:** Separation of Concerns, configuration and secrets are managed separately. Secrets are more secure than ConfigMaps. Access to them can be controlled more strictly using Kubernetes **RBAC** (Role-Based Access Control).
*   **High-availability:** Uses Canary deployment with rollout updates and Prometheus metrics validation for increased reliabilty.
*   **Automation:** From Dev to Prod a client script on Github Actions handles the building, testing, deployment and runs the endpoint validation to create the latest stable version