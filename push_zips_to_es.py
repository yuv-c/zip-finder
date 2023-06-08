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
COL_INDEX_TO_NAME = {
    1: "LocationID",
    2: "City Name",
    3: "StreetID",
    4: "Street Name",
    5: "House Number",
    6: "Entrance",
    7: "ZIP 7",
    8: "Remark",
    9: "Updated",
}

INDEX = "address-to-zip"


def drop_missing_data(chunk: pd.DataFrame) -> pd.DataFrame:
    return chunk.dropna(subset=["House Number", "Street Name", "Location Name", "ZIP 7"])


def drop_rows_with_bad_data(chunk: pd.DataFrame) -> pd.DataFrame:
    bad_rows = chunk[
        (chunk["StreetID"].str.len() < 5) |
        (chunk["LocationID"].str.len() <= 0) |
        (chunk["ZIP 7"].str.len() < 7) |
        (chunk["House Number"] < 0) |
        (~chunk["StreetID"].str.isnumeric()) |
        (~chunk["LocationID"].str.isnumeric()) |
        (~chunk["ZIP 7"].str.isnumeric())
        ]
    try:
        chunk.drop(bad_rows.index, inplace=True)
        return chunk
    except Exception as e:
        print(e)
        return chunk


def cast_types(chunk: pd.DataFrame) -> pd.DataFrame:
    chunk["StreetID"] = chunk["StreetID"].astype(int).astype(str)
    chunk["LocationID"] = chunk["LocationID"].astype(int).astype(str)
    chunk["ZIP 7"] = chunk["ZIP 7"].astype(int).astype(str)
    chunk["House Number"] = chunk["House Number"].astype(int)
    chunk["Address Updated"] = pd.to_datetime(chunk["Updated"], format="%Y%m%d")
    chunk["timestamp"] = pd.to_datetime("now")
    return chunk


async def create_index(es_client: ElasticSearchClient) -> None:
    mapping = {
        "mappings": {
            "properties": {
                "row_num": {"type": "integer"},
                "loc_id": {"type": "integer"},
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
    csv_reader = pd.read_csv(ZIP_CODES_FILE, chunksize=rows_step_size)

    for chunk_num, chunk in enumerate(csv_reader):
        logging.info(f"Processing chunk {chunk_num}")
        chunk = drop_missing_data(chunk)
        chunk = cast_types(chunk)
        chunk = drop_rows_with_bad_data(chunk)
        chunk.fillna("", inplace=True)
        logging.info(f"Pushing chunk {chunk_num} to ES with {len(chunk.index)} rows")
        es_client.bulk_push_df_to_elasticsearch(df=chunk, index=INDEX)


if __name__ == "__main__":
    start = time.perf_counter()
    asyncio.run(main=main())
    print(f"{__file__} executed in {time.perf_counter() - start:0.2f} seconds.")
