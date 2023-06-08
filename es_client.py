from elasticsearch import Elasticsearch, RequestsHttpConnection
from elasticsearch import helpers
import config
import logging
from typing import List, Optional, Dict, Any
import pandas as pd

class ElasticSearchClient(object):
    def __init__(self, es_endpoint: str = config.ES_ENDPOINT,
                 es_index: str = config.ES_INDEX,
                 es_port: int = 9200,
                 es_username: str = config.ES_USERNAME,
                 es_password: str = config.ES_PASSWORD
                 ):

        self._es_endpoint = es_endpoint
        self._es_index = es_index
        self._es_port = es_port
        self._client = Elasticsearch(
            hosts=[{'host': self._es_endpoint, 'port': self._es_port}],
            http_auth=(es_username, es_password),
            use_ssl=False,
            verify_certs=False,
            connection_class=RequestsHttpConnection
        )

    @property
    def client(self) -> Elasticsearch:
        return self._client

    def create_index(self, index: str, body: Optional[Dict[str, Any]] = None) -> None:
        logging.info(f"Creating index {index} at {self._es_endpoint}.")
        try:
            if body is None:
                self._client.indices.create(index=index)
            else:
                self._client.indices.create(index=index, body=body)
            logging.info(f"Success creating index {index}.")
        except Exception as e:
            logging.error(f"Error creating index {index}: {e}")

    def delete_index(self, index: str) -> None:
        logging.info(f"Deleting index {index} from {self._es_endpoint}.")
        self._client.indices.delete(index)
        logging.info(f"Success deleting index {index}.")

    def delete_all_docs_from_index_but_keep_the_mapping(self, index: str) -> None:
        payload = {"query": {"match_all": {}}}
        logging.info(f"Deleting all documents from {index} index.")
        self._client.delete_by_query(index=index, body=payload)
        logging.info(f"Success deleting all documents from {index} index.")

    def get_indexes_data(self) -> dict:
        logging.info(f"Getting indexes object from {self._es_endpoint}")
        res = self._client.indices.get("*")
        logging.info(f"Success getting indexes object.")
        return res

    @staticmethod
    def _payload_constructor(df: pd.DataFrame, index: str) -> List[dict]:
        payload_df = pd.DataFrame()

        payload_df["_id"] = df["ZIP 7"]
        payload_df["_source"] = df.apply(dict, axis=1)
        payload_df["_index"] = index

        return payload_df.to_dict("records")

    def bulk_push_df_to_elasticsearch(self, df: pd.DataFrame, index: str = None) -> None:
        if len(df.index) == 0:
            logging.warning("Empty list of documents provided. Nothing to push.")
            return

        index = index or self._es_index
        payload = self._payload_constructor(df, index)
        logging.debug(f"Pushing the following payload: {payload}")

        logging.info(f"Pushing {len(df)} documents to {index} index.")
        helpers.bulk(self._client, payload)
        logging.info(f"Success pushing documents to {index} index.")

    def connection_check(self) -> bool:
        logging.info(f"Checking connection to {self._es_endpoint}.")
        try:
            assert self._client.ping()  # returns True if connection is successful
        except AssertionError:
            logging.error(f"Connection to {self._es_endpoint} failed.")
            return False
