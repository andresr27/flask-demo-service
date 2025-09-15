#!/bin/bash
#!/usr/bin/env bash

function usage {
    echo "Usage: ./deploy.sh [test | up | down | post]"
    echo "    test   : runs the full test suite within the test environment"
    echo "    up     : brings up a clean test environment"
    echo "    down   : brings down the test environment"
    echo "    post   : runs the post build steps"
    echo "    deploy <environment> : runs the deployment steps on the give environment"
}

function validate {
    last_return_code=$?
    if [ $last_return_code -ne 0 ]; then
        echo "$1 with $last_return_code"
        exit 1
    fi
}

function action_up {
    ENVIRONMENT=$1
    ENVIRONMENT="Dev"

    if [[ $(mikube status "not running" ) ]]; then
        echo "Starting minikube"
        minikube start
        minikube addons enable ingress
        kubectl config use-context minikube
    fi
    validate "Minikube starting failed"
    echo "Minikube is running and configure for Kubectl"
}

function action_down {
    echo "Bringing down the test environment..."
    minikube stop
    #docker volume prune -f >/dev/null
    #validate "docker volume prune -f failed"
}

function action_test {
    echo "Running the full test suite..."

    # bring up a clean test environment first because we have UTs that hit the DB
    # should really be done after successful UT pass
    action_up "Dev"

    # Docker image built
    # We should deployment to force update on change and to be able to rollback to specific versions
    docker build -t "${IMAGE_URL}":canary .
    validate "Docker image build failed"

    # run unit tests
    #python unittest
    #validate "Python unittest failed"

    # run integration tests
    # integrationTest
    #validate "Python integration tests failed"

    # generate docs
    # bring down the test environment
    #action_down
}

function action_post {
    echo "Running post build against branch=$BUILD_SOURCE_VERSION"

    # Do we want to save test result
    if [ -d app/build/reports/tests ]; then
        echo "Copying server test output to S3 artifacts"
        aws s3 sync app/build/reports/tests s3://demo-services-builds/artifacts/"$BUILD_TAG"/tests --only-show-errors
    fi
    # Do we want to build docs
    DEPLOY_VERSION=$(git describe)
}


function action_deploy {
    ENVIRONMENT=$1

    echo "Running deploy of branch=canary to environment=${ENVIRONMENT}"

    # setup config, note that we're going to switch directories next so this has to be an absolute path

    case $ENVIRONMENT in
      dev)
        # ToDo Validate ENV vars are set
        echo "Deployment for ${IMAGE_URL}:${DEPLOY_VERSION} Dev in progress..."
        ;;

      prod)
        KUBECONFIG="$(aws secrets get-secret --name "${CLUSTER_NAME}" --output text --query Parameter.Value)"
        export KUBECONFIG
        echo "Deployment for ${IMAGE_URL} to ${CLUSTER_NAME} in progress..."
        # get aws region being deployed to before changing directory
        ;;
     *)
        echo "Unknown action ($1)"
        usage
        ;;
    esac

    # switch to the appropriate kubernetes directory
    pushd "./kubernetes/${ENVIRONMENT}" || exit

    # Edit image
    kubectl set image deployment demo-service-canary -n "${NAMESPACE}" demo-service="${IMAGE_URL}":"${DEPLOY_VERSION}"
    kubectl patch secret demo-service-secrets -n "${NAMESPACE}" -p="{\"data\":{\"api_key\":\"$(echo -n "${API_KEY}" | base64)\"}}"


    # Scale up canary
    kubectl scale deployment/demo-service-canary --replicas=1

    # switch back to the original directory
    popd || exit


    # deploy Zabbix alert
    #export ZABBIX_AUTHORIZATION="$(aws ssm get-parameter --name "prod/$ZABBIX_TOKEN" --output text --query Parameter.Value)"
    #export ZABBIX_HOST=$(cat ../deployment/"$REGION"/"$ENVIRONMENT"/grafana-host)
    #zabbix-deployer deploy

    # Validate Canary and
    # Promote version
    # Scale down Canary

}


case "$1" in
    test)
        action_test
        ;;
    up)
        action_up "$2"
        ;;
    down)
        action_down
        ;;
    post)
        action_post
        ;;
    canary)
        action_deploy "$2"
        ;;
    *)
        echo "Unknown action ($1)"
        usage
        ;;
esac
