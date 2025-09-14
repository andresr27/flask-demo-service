#!/bin/bash
# Process the deployment template
source .env

pushd app || exit
# lint code
#docker build -t ${IMAGE_URL}:stable .
# if prod docker push
popd || exit

pwd
pushd kubernetes/dev || exit
kubectl apply -f .
popd || exit


#cat deployment.yaml | envsubst '${IMAGE_URL}' | kubectl apply -f -
#echo -n $FLIGHTS_API_KEY | base64



echo "Deployment for ${IMAGE_URL} in progress..."