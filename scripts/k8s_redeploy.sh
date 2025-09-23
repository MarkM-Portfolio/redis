#!/bin/bash

#TODO: Refactoring in order to get complience with the lates HA Proxy and Statefulsets implementation
#TODO: What does the variable 'IS_FEATURE' stand for? Please if possible, get it refactored in order to be more cohesive (eg.: what feature is that?)
k8s_redeploy() {
    if [ $IS_FEATURE == true ] && [ $DEBUG_BUILD_ALL != true ]; then
	echo "k8s_redeploy: skipping redis"
    else
        echo "k8s_redeploy: deploying redis"
        kubectl delete --ignore-not-found -n connections -f deployment/kubernetes/
        kubectl create -n connections -f deployment/kubernetes/
    fi
}

k8s_redeploy
