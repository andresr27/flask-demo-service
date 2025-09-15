#!/bin/bash
# Deploy to Dev
source .env
pushd app || exit
# lint code
# Change kubeconfig to minikube, for safety
docker build -t ${IMAGE_URL}:stable .
# if prod docker push
popd || exit

# Deploy to k8s
pushd kubernetes/dev || exit
# We want to set the new image and roll out a restart or simply wait K8s does this for us
# If deploy not running apply all else just canary. Actions should handle the promotion with cli.sh?
kubectl apply -f
popd || exit

echo "Deployment for ${IMAGE_URL} in progress..."
