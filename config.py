import os
from dotenv import load_dotenv

load_dotenv()

AWS_DEFAULT_REGION = "eu-central-1"
AWS_ZIP_INDEX = "address-to-zip"

ES_ENDPOINT = os.getenv("ES_ENDPOINT")
ES_INDEX = os.getenv("ES_INDEX")
