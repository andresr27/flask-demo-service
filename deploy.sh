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

function action_up {
    ENVIRONMENT=$1
    ENVIRONMENT="Dev"

    if [[ $(mikube status "not running" ) ]]; then
        echo "Starting minikube"
        minikube start
    fi
    validate_success "Minikube starting failed"
    echo "Minkube is running"

    ENVIRONMENT="Test"

    if [[ $(mikube status "running") ]]; then
        echo "Verify test environment is running"
        action_down
    fi

    echo "Bringing up a clean test environment..."
    minikube start
}

function action_down {
    echo "Bringing down the test environment..."
    minikube delete
    docker volume prune -f >/dev/null
    validate_success "docker volume prune -f failed"
}

function action_test {
    echo "Running the full test suite..."

    # bring up a clean test environment first because we have UTs that hit the DB
    # should really be done after successful UT pass
    action_up "Dev"

    # Docker image built
    # We should deployment to force update on change and to be able to rollback to specific versions
    docker build -t "${IMAGE_URL}":canary .
    validate_success "Docker image build failed"

    # run unit tests
    #python unittest
    validate_success "Python unittest failed"

    # run integration tests
    # integrationTest
    validate_success "Python integration tests failed"

    # generate docs
    # bring down the test environment
    action_down
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
        echo "Deployment for ${IMAGE_URL} Dev in progress..."
        ;;

      prod)
        export KUBECONFIG=$PWD/../demo-cluster/${ENVIRONMENT}/config
        source "$PWD/../demo-cluster/dev/.env"
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
        kubectl set image deployment.apps/demo-service-canary -n="${NAMESPACE}" "${IMAGE_URL}":"${DEPLOY_VERSION}"
        kubectl edit add secret demo-service-secrets -n="${NAMESPACE}"--from-literal=APY_KEY="${API_KEY}"

        # Scale up canary
        kubectl scale deployment/<deployment-name> --replicas=1

        # switch back to the original directory
        popd || exit


        # deploy Zabbix alert
        #export ZABBIX_AUTHORIZATION="$(aws ssm get-parameter --region "$ZABBIX_TOKEN" --name "ZABBIX_CREDENTIALS" --output text --query Parameter.Value)"
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
    deploy)
        action_deploy "$2"
        ;;
    *)
        echo "Unknown action ($1)"
        usage
        ;;
esac
