#!/bin/sh
#
# See:
# https://www.youtube.com/watch?v=zcA4QboET5Q
# https://github.com/googleapis/nodejs-iot/blob/main/samples/http_example/cloudiot_http_example.js
#
###########################################################################################

REGION_IOT=asia-east1
REGISTRY_ID=my-registry
DEVICE_ID=helicoter-123

DATASET=my_dataset # hyphen not allowed
TABLE=my_table

NUM_MESSAGES=${NUM_MESSAGES-20}

echo ">>> Simulating sensor messages > cloud iot > pubsub > dataflow > bq ($DATASET.$TABLE)"
echo ">>> Please wait ..."
echo

# node_modules for simulation
if [ ! -d nodejs-iot/node_modules ]; then
    (cd nodejs-iot && npm install)
fi

(cd nodejs-iot && \
    node cloudiot_http_example.js \
    --cloudRegion=$REGION_IOT \
    --registryId=$REGISTRY_ID \
    --deviceId=$DEVICE_ID \
    --privateKeyFile=../rsa_private.pem \
    --algorithm=RS256 \
    --numMessages=$NUM_MESSAGES)

echo ">>> $0 done."
echo ">>> Please wait a few mins for 'prediction' data to show up."
