import asyncio
import logging
import time
from es_client import ElasticSearchClient
import pandas as pd
import os
from dotenv import load_dotenv

LOG_FORMAT = "%(asctime)s | %(levelname)s | %(name)s | %(module)s | %(lineno)d | %(message)s"
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)

load_dotenv()

ZIP_CODES_FILE = "zip-codes.csv"
COL_NAMES = [
    'city_id',
    'city_name',
    'street_id',
    'street_name',
    'house_number',
    'entrance',
    'zip_code',
    'remark',
    'updated'
]

INDEX = "address-to-zip"


def drop_missing_data(chunk: pd.DataFrame) -> pd.DataFrame:
    return chunk.dropna(subset=["house_number", "street_name", "city_name", "zip_code"])


def drop_rows_with_bad_data(chunk: pd.DataFrame) -> pd.DataFrame:
    bad_rows = chunk[
        (chunk["street_id"].str.len() < 5) |
        (chunk["city_id"].str.len() <= 0) |
        (chunk["zip_code"].str.len() < 7) |
        (chunk["house_number"].astype(int) < 0) |
        (~chunk["street_id"].str.isnumeric()) |
        (~chunk["city_id"].str.isnumeric()) |
        (~chunk["zip_code"].str.isnumeric())
        ]
    try:
        chunk.drop(bad_rows.index, inplace=True)
        return chunk
    except Exception as e:
        print(e)
        return chunk


def cast_types(chunk: pd.DataFrame) -> pd.DataFrame:
    chunk["street_id"] = chunk["street_id"].astype(int).astype(str)
    chunk["city_id"] = chunk["city_id"].astype(int).astype(str)
    chunk["zip_code"] = chunk["zip_code"].astype(int).astype(str)
    chunk["house_number"] = chunk["house_number"].astype(str)  # To enable free
    chunk["updated"] = pd.to_datetime(chunk["updated"], format="%Y%m%d")
    chunk["updated"] = chunk["updated"].dt.strftime("%Y-%m-%d %H:%M:%S")
    chunk["timestamp"] = pd.to_datetime("now")
    return chunk


def add_full_address_field(chunk: pd.DataFrame) -> pd.DataFrame:
    chunk["full_address"] = chunk["city_name"] + " " + chunk["street_name"]
    return chunk


async def create_index(es_client: ElasticSearchClient) -> None:
    mapping = {
        "mappings": {
            "properties": {
                "city_id": {"type": "integer"},
                "city_name": {"type": "text",
                              "analyzer": "hebrew"},
                "street_id": {"type": "integer"},
                "street_name": {"type": "text",
                                "analyzer": "hebrew"},
                "house_number": {"type": "text"},
                "entrance": {"type": "text",
                             "analyzer": "hebrew"},
                "zip_code": {"type": "integer"},
                "remark": {"type": "text",
                           "analyzer": "hebrew"},
                "updated": {"type": "date",
                            "format": "yyyy-MM-dd HH:mm:ss"},
                "timestamp": {"type": "date",
                              "format": "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"}
            }
        }
    }
    es_client.create_index(index=INDEX, body=mapping)


async def main() -> None:
    es_client = ElasticSearchClient(es_endpoint=os.getenv("ES_ENDPOINT"), es_index=INDEX,
                                    es_port=9200)  # use the ElasticSearchClient

    if input("Do you want to delete and recreate the index? (y/n)") == "y":
        logging.info("Deleting index")
        es_client.delete_index(index=INDEX)
        logging.info(f"Index {INDEX} deleted. Creating index...")
        await create_index(es_client=es_client)

    rows_step_size = 10000
    csv_reader = pd.read_csv(ZIP_CODES_FILE, chunksize=rows_step_size, names=COL_NAMES, header=None)

    for chunk_num, chunk in enumerate(csv_reader):
        logging.info(f"Processing chunk {chunk_num}")

        if chunk_num == 0:  # skip header
            chunk = chunk[1:]

        chunk = drop_missing_data(chunk)
        chunk = cast_types(chunk)
        chunk = drop_rows_with_bad_data(chunk)
        chunk = add_full_address_field(chunk)
        chunk.fillna("", inplace=True)

        logging.info(f"Pushing chunk {chunk_num} to ES with {len(chunk.index)} rows")
        es_client.bulk_push_df_to_elasticsearch(df=chunk, index=INDEX)


if __name__ == "__main__":
    start = time.perf_counter()
    asyncio.run(main=main())
    print(f"{__file__} executed in {time.perf_counter() - start:0.2f} seconds.")
