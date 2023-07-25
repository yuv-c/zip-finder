import json
import os
import re
import requests
from typing import Tuple
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)
LOG_FORMAT = "%(asctime)s | %(levelname)s | %(name)s | %(module)s | %(lineno)d | %(message)s"
logging.basicConfig(format=LOG_FORMAT)

HEADERS = {
    'Access-Control-Allow-Origin': os.getenv('CLOUDFRONT_URL'),
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
}


def process_input(input_string: str) -> Tuple[str, str, str]:
    address, city = [x.strip() for x in input_string.split(",")]

    house_number = re.search(r'\d+', address).group()

    street_name = re.sub(house_number, '', address).strip()

    return street_name, house_number, city


def lambda_handler(event, context):
    logger.info(f"Received event: {event}")

    try:
        body = json.loads(event.get('body'))

        input_string = body.get('zip_code')

        logger.info(f"Received address: {input_string}")

        street, house_number, city = process_input(input_string)

        query = {
            "query": {
                "bool": {
                    "must": [
                        {
                            "bool": {
                                "should": [
                                    {
                                        "fuzzy": {
                                            "street_name.keyword": {
                                                "value": street,
                                                "prefix_length": 2,
                                                "max_expansions": 100
                                            }
                                        }
                                    },
                                    {
                                        "match_phrase": {
                                            "street_name.keyword": street
                                        }
                                    }
                                ]
                            }
                        },
                        {
                            "bool": {
                                "should": [
                                    {
                                        "fuzzy": {
                                            "city_name.keyword": {
                                                "value": city,
                                                "prefix_length": 3,
                                                "max_expansions": 100
                                            }
                                        }
                                    },
                                    {
                                        "match_phrase": {
                                            "city_name.keyword": city
                                        }
                                    }
                                ]
                            }
                        },
                        {
                            "match": {
                                "house_number": house_number
                            }
                        }
                    ]
                }
            },
            "size": 5
        }

        es_endpoint = os.getenv('ES_ENDPOINT')
        response = requests.get(f"http://{es_endpoint}:9200/address-to-zip/_search", json=query)
        es_response = response.json()

        processed_response = es_response
        logger.info(f"Processed response: {processed_response}")

        return {
            'statusCode': 200,
            'body': json.dumps(processed_response),
            'headers': HEADERS,
        }

    except ValueError as e:
        logger.error(f"ValueError caught: {e}")
        return {
            'statusCode': 400,
            'body': json.dumps({"error": str(e)}),
            'headers': HEADERS,
        }
