#!/bin/sh
#
# See also:
# labs/month3/Elastic Google Cloud Infrastructure: Scaling and Automation/Configure an HTTP Load Balancer with Autoscaling/lab.sh
# labs/month3/Networking in Google Cloud: Defining and Implementing Networks/Caching Cloud Storage content with Cloud CDN/lab.sh
# 
# https://cloud.google.com/load-balancing/docs/https/ext-load-balancer-backend-buckets#creating_the_http_load_balancer_with_backend_buckets
#
###########################################################################################

# Do NOT change the settings here - adjust in Makefile

PROJECT_ID=$DEVSHELL_PROJECT_ID
ZONE=${ZONE-"asia-southeast1-a"}
REGION=${REGION-"asia-southeast1"}
BUCKET=${PROJECT_ID}-6m13-demo

cat <<EOF
#################################################
##
## Setting up managed instance group, backend-service/bucket, http(s) lb ...
##
#################################################
EOF

alias gcloud='gcloud --quiet'

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

gcloud services enable compute.googleapis.com


###############
# Create cloud storage (for static vod content) & backend bucket w/ cdn

gsutil mb -l $REGION -b on gs://$BUCKET
gsutil iam ch allUsers:objectViewer gs://$BUCKET

gcloud compute backend-buckets create storage-backend \
    --gcs-bucket-name=$BUCKET \
    --enable-cdn \
    --cache-mode=CACHE_ALL_STATIC


###############
# fw & nat & health-check

gcloud compute firewall-rules create fw-health-check \
    --allow=tcp:80 \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=allow-health-checks

gcloud compute routers create nat-router \
    --network=default \
    --region=$REGION

gcloud compute routers nats create nat-config \
    --region=$REGION \
    --router=nat-router \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges

gcloud compute health-checks create tcp health-check \
    --timeout=5 \
    --check-interval=10 \
    --unhealthy-threshold=3 \
    --healthy-threshold=2 \
    --port=80


###############
# Create instance template
# For re-streaming, n1-standard-1/2 is good enough

sed -i "s~^YOUTUBE.*~YOUTUBE_LIVE_STREAM=$YOUTUBE_LIVE_STREAM~" assets/vmstartup.sh

gcloud compute instance-templates create vm-template \
    --region=$REGION \
    --no-address \
    --machine-type=n1-standard-2 \
    --tags=allow-health-checks \
    --metadata-from-file="startup-script=assets/vmstartup.sh"


echo sleep 1m to stabilize ...
sleep 1m

###############
# Create managed instance group & backend service
# vmstartup.sh expects ~60s from start to ready (install nginx, ffmpeg etc)
# Create multiple instance groups for "emerging regions" and add them in
# 'backend-services add-backend' later. Here, we keep demo simple.

gcloud compute instance-groups managed create vm-instance-group \
    --template=vm-template \
    --size=1 \
    --zones=$ZONE \
    --health-check=health-check \
    --initial-delay=100

gcloud compute instance-groups managed set-autoscaling vm-instance-group \
    --region=$REGION \
    --cool-down-period=60 \
    --max-num-replicas=3 \
    --min-num-replicas=1 \
    --target-load-balancing-utilization=0.8 \
    --mode=on

# session-affinity=CLIENT_IP as re-stream of hls is somewhat 'stateful'

gcloud compute backend-services create vm-backend \
    --protocol=HTTP \
    --session-affinity=CLIENT_IP \
    --port-name=http \
    --health-checks=health-check \
    --global

# Re-streaming is I/O ops mainly so balancing-mode set as RATE
# GCE bandwidth is ~ 10-30 Gbps = 1.2+ GBps, HD bandwidth ~ 0.4MBps so each instance
# can serve 2k+ clients concurrently. Our ts timespan is 10s, hence max-rate ~ 200.

gcloud compute backend-services add-backend vm-backend \
    --instance-group=vm-instance-group \
    --instance-group-region=$REGION \
    --balancing-mode=RATE \
    --max-rate-per-instance=200 \
    --capacity-scaler=1 \
    --global


###############
# Create url mappings

gcloud compute url-maps create url-map \
    --default-service vm-backend

gcloud compute url-maps add-path-matcher url-map \
    --path-matcher-name=path-matcher \
    --new-hosts=* \
    --backend-bucket-path-rules="/static/*=storage-backend" \
    --default-service=vm-backend


###############
# Finally, create http(s) lb

gcloud compute target-http-proxies create lb \
    --url-map=url-map

gcloud compute forwarding-rules create lb-forwarding-rule \
    --global \
    --ip-version=IPV4 \
    --target-http-proxy=lb \
    --ports=80


LB_IP=$(gcloud compute forwarding-rules describe lb-forwarding-rule --global --format='value(IPAddress)')

echo $LB_IP > .info

echo
echo ">>> $0 done. Please allow 2-3 mins to stabilize."
echo ">>> Re-streaming url: http://$LB_IP/"
