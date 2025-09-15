#!/bin/bash
# Deploy to Dev
source .env
pushd app || exit
# lint code
# Change kubeconfig to minikube, for safety
docker build -t ${IMAGE_URL}:stable .
# if prod docker push
popd || exit

pwd
pushd kubernetes/dev || exit
kubectl apply -f .
popd || exit




echo "Deployment for ${IMAGE_URL} in progress..."