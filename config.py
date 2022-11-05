import os
from dotenv import load_dotenv

load_dotenv()

AWS_OS_ENDPOINT = os.getenv("AWS_OS_ENDPOINT")
AWS_OS_ACCESS_KEY = os.getenv("AWS_OS_ACCESS_KEY")
AWS_OS_SECRET_KEY = os.getenv("AWS_OS_SECRET_KEY")
AWS_DEFAULT_KMS_KEY_ID = os.getenv("AWS_DEFAULT_KMS_KEY_ID")
AWS_DEFAULT_REGION = "eu-central-1"
AWS_ZIP_INDEX = "address-to-zip"
