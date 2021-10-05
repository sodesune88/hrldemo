#!/bin/sh
#
# Refs:
# https://cloud.google.com/iot/docs/quickstart
# https://cloud.google.com/iot/docs/how-tos/devices
#
#######################################################

# Do NOT change the settings here - adjust in Makefile

PROJECT_ID=$DEVSHELL_PROJECT_ID
ZONE=${ZONE-"asia-southeast1-a"}
REGION_IOT=asia-east1  # Valid regions: {asia-east1,europe-west1,us-central1}
BUCKET_IOT=${PROJECT_ID}-6m13-demo-iot

REGISTRY_ID=my-registry
DEVICE_ID=helicoter-123
TOPIC_ID=my-device-events

DATASET=my_dataset # hyphen not allowed
TABLE=my_table

cat <<EOF
#################################################
##
## Setting cloud iot > pubsub > dataflow > biqquery ...
##
#################################################
EOF

alias gcloud='gcloud --quiet'

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

gcloud services enable pubsub.googleapis.com cloudiot.googleapis.com dataflow.googleapis.com

gsutil mb -l $REGION_IOT -b on gs://$BUCKET_IOT


# Create pubsub topic

gcloud pubsub topics create $TOPIC_ID


# Generate private/public keypair

openssl req -x509 -newkey rsa:2048 -keyout rsa_private.pem --nodes -out rsa_public.pem -subj "/CN=unused"


# Create iot registry

gcloud iot registries create $REGISTRY_ID \
    --project=$PROJECT_ID \
    --region=$REGION_IOT \
    --event-notification-config=topic=$TOPIC_ID \
    --enable-http-config


# Create device - different ID for different helicopters
    
gcloud iot devices create $DEVICE_ID \
  --project=$PROJECT_ID \
  --region=$REGION_IOT \
  --registry=$REGISTRY_ID \
  --public-key path=rsa_public.pem,type=rsa-x509-pem


# Create bigquery dataset

bq mk --location=$REGION_IOT --dataset $DATASET


# Setup dataflow

if [ ! -f tempenv/bin/activate ]; then  
    python3 -m virtualenv tempenv
    source tempenv/bin/activate
    pip install apache-beam[gcp] -q
else
    source tempenv/bin/activate
fi

# dataflow api takes a while to be effective ...
echo sleep 2m to stabilize ...
sleep 2m

python3 pubsubdataflowbigquery.py --project=$PROJECT_ID \
    --input_topic=projects/$PROJECT_ID/topics/$TOPIC_ID \
    --runner=DataflowRunner --temp_location=gs://$BUCKET_IOT/tmp \
    --output_bigquery=$DATASET.$TABLE --region=$REGION_IOT

deactivate


echo
echo ">>> $0 done. Please wait a while before running simulation."
