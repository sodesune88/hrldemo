#!/bin/sh
#
# See:
# https://cloud.google.com/transcoder/docs/quickstart
#
###########################################################################################

VOD=${VOD-assets/bunny.webm}

PROJECT_ID=$DEVSHELL_PROJECT_ID
ZONE=${ZONE-"asia-southeast1-a"}
REGION=${REGION-"asia-southeast1"}
BUCKET=${PROJECT_ID}-6m13-demo
LOCATION=asia-east1 # https://cloud.google.com/transcoder/docs/locations

cat <<EOF
#################################################
##
## Demo transcoder api ...
##
#################################################
EOF

gcloud services enable transcoder.googleapis.com

gsutil cp $VOD gs://$BUCKET/static/

VOD=`basename $VOD`                             # bunny.webm
VOD_NAME=`echo ${VOD%.*} | sed 's/\./-/g'`      # bunny

mkdir -p .tmp

cat <<EOF > .tmp/req.json
{
  "inputUri": "gs://$BUCKET/static/$VOD",
  "outputUri": "gs://$BUCKET/static/output/$VOD_NAME/"
}
EOF


# Submit job

OK=
URL=https://transcoder.googleapis.com/v1/projects/$PROJECT_ID/locations/$LOCATION/jobs

curl -X POST \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d @.tmp/req.json \
    $URL | tee .tmp/log


# Wait for job

JOB=`cat .tmp/log | jq -r '.name' | rev | cut -d/ -f1 | rev`
URL=$URL/$JOB

for i in 5 10 20 40 40 40 40; do
    if curl -sX GET -H "Authorization: Bearer $(gcloud auth print-access-token)" $URL \
        | jq -r .state \
        | grep SUCCEEDED; then
        OK=1
        break
    fi
    echo waiting ${i}s for job to complete ...
    sleep $i
done


# Delete job (else auto remove after 30 days)

curl -sX DELETE -H "Authorization: Bearer $(gcloud auth print-access-token)" $URL

if [ -z "$OK" ]; then
   echo "Transcoding job not completed. Bailing out. Pls check your VOD file."
   exit 1
fi

cat <<EOF >.tmp/$VOD_NAME.html
<video controls autoplay><source src=/static/output/$VOD_NAME/sd.mp4 type=video/mp4></video>
EOF

gsutil cp .tmp/$VOD_NAME.html gs://$BUCKET/static/


echo
echo ">>> $0 done."
echo ">>> Transcoded files can be found @ gs://$BUCKET/static/output/$VOD_NAME/"
echo ">>> Vod url (cdn): http://$(cat .info)/static/$VOD_NAME.html"
