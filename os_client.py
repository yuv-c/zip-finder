import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection, AWSV4SignerAuth, client, exceptions
import config
import json
import logging
from typing import List


# async def get_os_client() -> client.OpenSearch:
#     credentials = boto3.Session(aws_access_key_id=config.AWS_OS_ACCESS_KEY,
#                                 aws_secret_access_key=config.AWS_OS_SECRET_KEY,
#                                 region_name=config.AWS_DEFAULT_REGION).get_credentials()
#     region = 'eu-central-1'  # for example
#     auth = AWSV4SignerAuth(credentials, region)
#     endpoint = config.AWS_OS_ENDPOINT
#     os_client = OpenSearch(
#         hosts=[{'host': endpoint, 'port': 443}],
#         http_auth=auth,
#         use_ssl=True,
#         verify_certs=True,
#         connection_class=RequestsHttpConnection
#     )
#
#     return os_client


# async def create_index():
#     document1 = {
#         "title": "Moneyball",
#         "director": "Bennett Miller",
#         "year": "2011"
#     }
#
#     document2 = {
#         "title": "Apollo 13",
#         "director": "Richie Cunningham",
#         "year": "1994"
#     }
#
#     data = [document1, document2]
#
#     my_index = 'my_index'
#
#     action = {
#         "index": {
#             "_index": my_index
#         }
#     }
#
#     def payload_constructor(data, action):
#         # "All my own work"
#
#         action_string = json.dumps(action) + "\n"
#
#         payload_string = ""
#
#         for datum in data:
#             payload_string += action_string
#             this_line = json.dumps(datum) + "\n"
#             payload_string += this_line
#         return payload_string
#
#     try:
#         response = os_client.indices.delete(my_index)
#         print('\nCreating index:')
#         print(response)
#     except Exception as e:
#         # If, for example, my_index already exists, do not much!
#         print(e)
#
#     response = os_client.bulk(body=payload_constructor(data, action), index=my_index)
#     print('\nBulk response:')
#     print(response)


class OpenSearchClient(object):
    """
    This is an overkill for the project. Wrote this for experimenting with OpenSearch.
    """

    def __init__(self, os_endpoint: str = None, os_index: str = None, access_key: str = None, secret_key: str = None,
                 region: str = None):
        self._aws_os_endpoint = os_endpoint or config.AWS_OS_ENDPOINT
        self._aws_os_index = os_index or config.AWS_ZIP_INDEX
        self._aws_access_key = access_key or config.AWS_OS_ACCESS_KEY
        self._aws_secret_key = secret_key or config.AWS_OS_SECRET_KEY
        self._aws_region = region or config.AWS_DEFAULT_REGION

        _credentials = boto3.Session(aws_access_key_id=self._aws_access_key,
                                     aws_secret_access_key=self._aws_secret_key,
                                     region_name=self._aws_region).get_credentials()

        auth = AWSV4SignerAuth(_credentials, self._aws_region)
        endpoint = config.AWS_OS_ENDPOINT
        self.client = OpenSearch(
            hosts=[{'host': endpoint, 'port': 443}],
            http_auth=auth,
            use_ssl=True,
            verify_certs=True,
            connection_class=RequestsHttpConnection
        )

    def client(self) -> client.OpenSearch:
        return self.client

    async def delete_index(self, index: str) -> None:
        try:
            logging.info(f"Deleting index {index} from {self._aws_os_endpoint}.")
            res = await self.client.indices.delete(index)
            res.raise_for_status()
            logging.info(f"Success deleting index {index}.")

        except exceptions.NotFoundError as not_found_error:  #
            logging.error(f"Requested resource not found: {not_found_error}")

        except Exception as e:  # TODO: Change to correct exception
            logging.error(f"Error encountered while creating index {index}. Error:\n{e}")

    async def create_index(self, index: str) -> None:
        try:
            logging.info(f"Creating index {index} at {self._aws_os_endpoint}.")
            res = await self.client.indices.delete(index)
            res.raise_for_status()
            logging.info(f"Success creating index {index}.")

        except exceptions.NotFoundError as not_found_error:  #
            logging.error(f"Requested resource not found: {not_found_error}")

        except Exception as e:  # TODO: Change to correct exception
            logging.error(f"Error encountered while creating index {index}. Error:\n{e}")

    async def get_indexes_data(self) -> list:
        url = f"{self._aws_os_endpoint}/_cat/indices"

        try:
            logging.info(f"Getting indexes list from {url}")
            res = await self.client.indices.get("*")
            res.raise_for_status()
            logging.info(f"Success getting indexes list.")
            text = await res.text()
            return [index.split()[2] for index in text.splitlines()]
        except exceptions.NotFoundError as e:  # TODO: Change to correct exception
            logging.error(f"Requested resource not found: {e}")
            return []

    @staticmethod
    def _payload_constructor(data: List[dict], index: str) -> str:
        action = json.dumps({
            "index": {
                "_index": index
            }
        }) + "\n"

        payload_string = ""

        for doc in data:
            payload_string += action
            payload_string += json.dumps(doc) + "\n"
        return payload_string

    async def bulk_push_to_open_search(self, documents: List[dict], index: str = None) -> None:
        index = index or self._aws_os_index
        payload = self._payload_constructor(documents, index)

        try:
            logging.info(f"Pushing {len(documents)} documents to {index} index.")
            res = await self.client.bulk(body=payload, index=index)
            res.raise_for_status()
            logging.info(f"Success pushing documents to {index} index.")
        except Exception as e: # TODO: Change to correct exception
            logging.error(f"HTTPError encountered while bulk pushing documents to {index} index. Error:\n{e}")
