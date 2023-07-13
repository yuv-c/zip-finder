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


def process_zip_code(zip_code: str) -> Tuple[str, str]:
    house_number = re.search(r'\d+', zip_code)

    if house_number is None:
        raise ValueError('No house number found in the provided address.')
    else:
        house_number = house_number.group()

    address = re.sub(r'\s*\b' + house_number + r'\b\s*', ' ', zip_code)

    address = address.strip()

    return house_number, address


def lambda_handler(event, context):
    logger.info(f"Received event: {event}")

    body = json.loads(event.get('body'))

    zip_code = body.get('zip_code')

    logger.info(f"Received zip_code: {zip_code}")

    house_number, address = process_zip_code(zip_code)

    query = {
        "query": {
            "bool": {
                "should": [
                    {
                        "multi_match": {
                            "query": address,
                            "fields": ["city_name", "street_name"]
                        }
                    },
                    {
                        "match": {
                            "full_address": {
                                "query": address,
                                "fuzziness": "AUTO"
                            }
                        }
                    }
                ],
                "must": [
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

    # TODO: Process the response
    processed_response = es_response

    return {
        'statusCode': 200,
        'body': json.dumps(processed_response)
    }
