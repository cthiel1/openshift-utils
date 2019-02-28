#!/bin/bash

set -e

log() {
  echo "[$(date +%F_%H:%M:%S)] - " $@
}

# AWS ECR Login
log "Executing AWS ECR Login"

ECR_LOGIN_OUTPUT=$( aws ecr get-login --region us-east-1 --no-include-email )
ECR_FQDN=$( echo $ECR_LOGIN_OUTPUT | cut -d' ' -f7 | cut -d'/' -f3 )
ECR_PASSWORD=$( echo $ECR_LOGIN_OUTPUT | cut -d' ' -f6 )

log "New AWS ECR token generated."

log "Login as system:admin ... " && oc login -u system:admin || log "Unable to connect to Openshift cluster"
oc version

log "Creating/Updating secrets and configure service account on Openshift"

PROJECTS=$(oc get projects --no-headers | awk '{print $1}')

SAs=(default deployer builder)

for project in $PROJECTS; do
  log "Project: $project"
  found=$(oc get secrets -n $project | grep aws-ecr | wc -l)
  if [[ $found -ne 0 ]]; then
    oc delete secret aws-ecr -n $project
  fi
  oc create secret docker-registry --docker-server=https://$ECR_FQDN --docker-username=AWS --docker-password=$ECR_PASSWORD aws-ecr -n $project
  log "Created secret aws-ecr"
  for sa in ${SAs[@]};do
    oc secrets add serviceaccount/$sa secrets/aws-ecr --for=pull -n $project
    log "Added secret to serviceaccount $sa"
  done
done

