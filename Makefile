export ZONE ?= asia-southeast1-a
export REGION ?= asia-southeast1
export TIMEZONE ?= Asia/Singapore

# Times Square live
export YOUTUBE_LIVE_STREAM ?= https://www.youtube.com/watch?v=AdUw5RdyZxI

# Sample video for cloud transcoder api
# https://cloud.google.com/transcoder/docs/concepts/overview
export VOD ?= assets/bunny.webm

##################################################################

all: main
.PHONY: log info clean

main:
	./setup_main.sh
	@touch $@

# make demo_transcoder VOD=path/to/vod
demo_transcoder: main
	./demo_transcoder.sh

export NUM_MESSAGES ?= 20
iot:
	./setup_iot.sh
	@touch $@

demo_iot: iot
	./demo_iot.sh

# show ip address of load-balancer
info: main
	cat .info

clean:
	@./clean.sh
	@rm -f main iot

veryclean:
	rm -rf .tmp .info *.pem tempenv */node_modules */package-lock.json
	gcloud services disable --quiet \
		pubsub.googleapis.com \
		dataflow.googleapis.com
	# removable only after 30 days of inactivity
	#gcloud services disable --quiet \
	#	cloudiot.googleapis.com \
	#	transcoder.googleapis.com \
	#	compute.googleapis.com
