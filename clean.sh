#!/bin/sh

ZONE=${ZONE-"asia-southeast1-a"}
REGION=${REGION-"asia-southeast1"}
REGION_IOT=asia-east1

# see setup_iot.sh
REGISTRY_ID=my-registry
DEVICE_ID=helicoter-123
TOPIC_ID=my-device-events
DATASET=my_dataset

alias gcloud='gcloud --quiet'

function destroy_iot() {
    JOBS=`gcloud dataflow jobs list --region=$REGION_IOT --format='value(JOB_ID)'`
    gcloud dataflow jobs cancel $JOBS --region=$REGION_IOT

    bq rm -r -f $DATASET

    gcloud iot devices delete $DEVICE_ID --region=$REGION_IOT --registry=$REGISTRY_ID --quiet
    gcloud iot registries delete $REGISTRY_ID --region=$REGION_IOT --quiet

    gcloud pubsub topics delete $TOPIC_ID
}

# in order of reverse dependencies!
function destroy_computes() {
    RESOURCES=(
        'firewall-rules'
        'routers'
        'forwarding-rules'
        'target-tcp-proxies'
        'target-http-proxies'
        'url-maps'
        'backend-services'
        'backend-buckets'
        'instance-groups managed'
        'instance-templates'
        'instances'
        'health-checks'
    )

    for res in "${RESOURCES[@]}"; do
        echo Cleaning $res ...
        if [ "$res" = "firewall-rules" ]; then
            # skip default created
            list="$(gcloud compute $res list --uri 2>/dev/null | grep -v '/default-')"
        else
            # skip those dataflow generated - they will be auto cleanup
            list="$(gcloud compute $res list --uri 2>/dev/null | grep -v 'beamapp')"
        fi
        [ -n "$list" ] && gcloud --quiet compute $res delete ${list}
    done    
}

function destroy_buckets() {
    for bucket in `gsutil ls`; do
        gsutil -m rm -r $bucket
    done
}


destroy_iot
destroy_computes
destroy_buckets

echo
echo done. all resources removed.
