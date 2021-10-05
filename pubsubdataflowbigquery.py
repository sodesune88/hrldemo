# Ref:
# https://github.com/GoogleCloudPlatform/dialogflow-log-parser-dataflow-bigquery

import argparse
import json
import time
import random
import logging

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.options.pipeline_options import SetupOptions
from apache_beam.options.pipeline_options import StandardOptions

bigquery_table_schema = {
    "fields": [
        { "mode": "NULLABLE",
          "name": "insertId",
          "type": "STRING"
        },
        { "mode": "NULLABLE",
          "name": "deviceId",
          "type": "STRING"
        },
        { "mode": "NULLABLE",
          "name": "timestamp",
          "type": "TIMESTAMP"
        },
        { "mode": "NULLABLE",
          "name": "overtakingProbability",
          "type": "FLOAT"
        }
    ]
}

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


def myfilter(d):
    """
    Only those 'interesting' predictions.
    Here we just filter half.

    :param d: json returned from ml_evaluate()
    """
    return d['overtakingProbability'] > 0.5

 
def run(argv=None, save_main_session=True):
    """Build and run the pipeline."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--input_topic', required=True,
        help=('Input PubSub topic of the form '
              '"projects/<PROJECT_ID>/topics/<TOPIC_ID>".'))
    parser.add_argument(
        '--output_bigquery', required=True,
        help=('Output BQ table to write results to '
              '"PROJECT_ID:DATASET.TABLE"'))
    known_args, pipeline_args = parser.parse_known_args(argv)

    pipeline_options = PipelineOptions(pipeline_args)
    pipeline_options.view_as(SetupOptions).save_main_session = save_main_session
    pipeline_options.view_as(StandardOptions).streaming = True
    p = beam.Pipeline(options=pipeline_options)
    
    ( p
      | 'From PubSub'     >> beam.io.ReadFromPubSub(topic=known_args.input_topic)
                                 .with_output_types(bytes)
      | 'To UTF-8'        >> beam.Map(lambda x: x.decode('utf-8'))
      | 'To Json'         >> beam.Map(json.loads)
      | 'ML Predict'      >> beam.Map(ml_evaluate)
      | 'MyFilter'        >> beam.Filter(myfilter)
      | 'WriteToBigQuery' >> beam.io.WriteToBigQuery(
                                 known_args.output_bigquery,
                                 schema=bigquery_table_schema,
                                 create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED,
                                 write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND
                             )
    )

    p.run()

if __name__ == '__main__':
    #logging.getLogger().setLevel(logging.INFO)
    run()
