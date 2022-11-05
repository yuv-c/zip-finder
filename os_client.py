import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection, AWSV4SignerAuth, client
import config
import json
import logging
from typing import List


class OpenSearchClient(object):
    """
    This is an overkill for the project. Wrote this for experimenting with OpenSearch.
    """

    def __init__(self, os_endpoint: str = config.AWS_OS_ENDPOINT,
                 os_index: str = config.AWS_ZIP_INDEX,
                 region: str = config.AWS_DEFAULT_REGION,
                 ):

        self._aws_os_endpoint = os_endpoint
        self._aws_os_index = os_index
        self._region = region
        _credentials = boto3.Session(profile_name="zip-codes-prod").get_credentials()

        auth = AWSV4SignerAuth(_credentials, self._region)
        endpoint = config.AWS_OS_ENDPOINT
        self._client = OpenSearch(
            hosts=[{'host': endpoint, 'port': 443}],
            http_auth=auth,
            use_ssl=True,
            verify_certs=True,
            connection_class=RequestsHttpConnection
        )

    def client(self) -> client.OpenSearch:
        return self._client

    def create_index(self, index: str) -> None:
        logging.info(f"Creating index {index} at {self._aws_os_endpoint}.")
        self._client.indices.create(index)
        logging.info(f"Success creating index {index}.")

    def delete_index(self, index: str) -> None:
        logging.info(f"Deleting index {index} from {self._aws_os_endpoint}.")
        self._client.indices.delete(index)
        logging.info(f"Success deleting index {index}.")

    def delete_all_docs_from_index_but_keep_the_mapping(self, index: str) -> None:
        payload = {"query": {"match_all": {}}}
        logging.info(f"Deleting all documents from {index} index.")
        self._client.delete_by_query(index=index, body=payload)
        logging.info(f"Success deleting all documents from {index} index.")

    def get_indexes_data(self) -> dict:
        url = f"{self._aws_os_endpoint}"
        logging.info(f"Getting indexes object from {url}")
        res = self._client.indices.get("*")
        logging.info(f"Success getting indexes object.")
        return res

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

    def bulk_push_to_open_search(self, list_of_docs: List[dict], index: str = None) -> None:
        index = index or self._aws_os_index
        payload = self._payload_constructor(list_of_docs, index)
        logging.debug(f"Pushing the following payload: {payload}")

        logging.info(f"Pushing {len(list_of_docs)} documents to {index} index.")
        self._client.bulk(body=payload, index=index)
        logging.info(f"Success pushing documents to {index} index.")

    def connection_check(self) -> bool:
        logging.info(f"Checking connection to {self._aws_os_endpoint}.")
        try:
            assert self._client.ping()  # returns True if connection is successful
        except AssertionError:
            logging.error(f"Connection to {self._aws_os_endpoint} failed.")
            return False
