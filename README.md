# Demo for Helicopter Racing League

## tl;dr

Login to [GCP console](https://console.cloud.google.com), create a new project, launch cloud shell, then:

    $ git clone https://github.com/sodesune/hrldemo
    $ cd hrldemo
    $ make

To demo [Transcoder API](https://cloud.google.com/transcoder/docs/concepts/overview):

    $ make demo_transcoder

To setup cloud iot > pubsub > dataflow > cloud AI (fake) > bigquery:

    $ make iot

To simulate helicopter iot-sensor messages to the pipeline:

    $ make demo_iot

To clean up **(Caution: this also removes ALL compute & storage resources, if exists earlier)**:

    $ make clean
    $ make veryclean (optional)

## Details

[Helicopter Racing League](./assets/master_case_study_helicopter_racing_league.pdf) [as of Oct/2021] - One of case studies for Google PCA exam.

### Real-time/live Streaming:

Current Google's Transporter API isn't ready for live/real-time streaming (yet). For migration (from existing cloub to GCP) they can port their existing live-transcoding solution over and simply choose VMs with higher computing powers, so as to "increase transcoding performance". 

To achieve "real-time content closer to users, with reduced latency", we setup repeaters/re-streamers using I/O optimized VMs as follows:

* managed instance group > backend service > http(s) load-balancer

```bash
$ make
...
>>> Re-streaming url: http://<load-balancer-ip>/
```

This creates resources stated above. Live feed from youtube ([https://www.youtube.com/watch?v=AdUw5RdyZxI](https://www.youtube.com/watch?v=AdUw5RdyZxI)) is used to represents **transcoded** stream and our instances in the group simply re-stream (same HLS format) using ffmpeg. See [assets/vmstartup.sh](./assets/vmstartup.sh). (ffmpeg auto-stop after 30min - ingress traffic FOC anyway).

To test different youtube feed (need to clean up 1st):
```bash
$ make YOUTUBE_LIVE_STREAM=https://www.youtube.com/watch?v=...
```

(AWS [live streaming solution](https://aws.amazon.com/solutions/implementations/live-streaming-on-aws/) transcodes live streams onto storage directly. This architecture is superior but discussion is beyond the scope...)

### VOD content

For recorded videos, the setup is:

* storage bucket > backend bucket > http(s) load-balancer > cdn

The backend bucket is hooked up with the same global balancer as live-streaming. Objects/ files stored in the bucket `gs://<project-id>-6m13-demo/static/` are mapped to `http://<load-balancer-ip>/static/` and cached by cloud cdn.

### VOD transcoding

```bash
$ make demo_transcoder
...
>>> Vod url (cdn): http://<load-balancer-ip>/static/<vod-name>.html
```

This copy sample vod file [assets/bunny.webm](./assets/bunny.webm) to `gs://<project-id>-6m13-demo/static/` and uses Google Transcoder API to transcode it. Transcoded videos can be found at `gs://<project-id>-6m13-demo/static/output/<vod-name>/*`.

To test different VOD file:

```bash
$ make demo_transcoder VOD=<path-to-vod-file>
```

### Real-time prediction of overtaking/ machine failures

Like F1 racing, the helicopters may have loads of sensors (IoT devices) attached sending large amount of raw data for real-time/ post analysis.

"Heli A is x meters trailing behind B, with speed/acceleration/direction/pressure/..., our AI/ML model predicts its chance of overtaking is y"

Similary for machine failures.

[Cloud AI/ Vertex AI](https://cloud.google.com/ai-platform/docs) is recommended for HRL. It supports [hyperparameter tuning](https://cloud.google.com/ai-platform/training/docs/using-hyperparameter-tuning) and distributed training. Quickstart guide is avail [here](https://cloud.google.com/ai-platform/docs/getting-started-keras). It is highly performant & serverless, making huge amount of real-time evaluations/ predictions possible.

```bash
$ make iot
```

This creates:

* cloud iot > pubsub > dataflow > cloud AI (fake) > bigquery.

[pubsubdataflowbigquery.py](./pubsubdataflowbigquery.py) (adapted from: [here](https://github.com/GoogleCloudPlatform/dialogflow-log-parser-dataflow-bigquery/blob/master/stackdriverdataflowbigquery.py)), illustrates how/ where ML evaluation can be invoked: 

```python
def ml_evaluate(d):
    """
    ML eval/predict here.
    see https://cloud.google.com/ai-platform/docs/getting-started-keras

    :param d: json from cloudiot_http_example.js
    """
    retval = {
        'insertId'              : hex(int(time.time()))[2:], # just for illustration
        'deviceId'              : None,
        'timestamp'             : None,
        'overtakingProbability' : None
    }

    try:
        retval['deviceId'] = d['deviceId']
        retval['timestamp'] = d['timestamp']

        speed = d['speed']
        pressure = d['pressure']
        # etc etc ...
        # invoke cloud ai w/ data here, but we fake ...
        retval['overtakingProbability'] = random.random()
    except:
        pass

    return retval
```

It also demostrates filter/transformation in dataflow. In our case, we filter half of predictions:

```python
def myfilter(d):
    """
    Only those 'interesting' predictions.
    Here we just filter half.

    :param d: json returned from ml_evaluate()
    """
    return d['overtakingProbability'] > 0.5
```

```bash
$ make demo_iot
```

This simulates 20 random helicopter iot-sensor messages (random 0-10 seconds interval in between).

[nodejs-iot/cloudiot_http_example.js](./nodejs-iot/cloudiot_http_example.js) (adapted from: [here](https://github.com/googleapis/nodejs-iot/blob/main/samples/http_example/cloudiot_http_example.js)): 

```javascript
const payload = JSON.stringify({
    insertId: Date.now() + '',
    deviceId: argv.deviceId,
    timestamp: new Date().toISOString(),
    speed: Math.floor(Math.random() * 1000),
    pressure: Math.random() // etc etc
})
```

Dataflow may also pipe to another pubsub, which can be used to trigger automatic overlays in real-time/live streaming.

### Other discussions

* "Race results prediction" - data/results from previous rounds can be used to ML evaluate winning chances for each team going into final round.

* "Crowd sentiment/ fan engagement prediction" - comments/ polls from HRL website can be used for sentiment analysis AI.

* "Support **ability to expose** the predictive models to partners" - deploy cloud endpoints/ apigee for management of HRL's API infra.


# License

Apache License, Version 2.0.