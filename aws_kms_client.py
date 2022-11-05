import boto3


class KMSClient(object):
    def __init__(self, key_id: str):
        self._session = boto3.Session(profile_name="zip-codes-prod")
        self._client = self._session.client('kms')
        self._key_id = key_id

    def client(self):
        return self._client

    def encrypt(self, data: str) -> bytes:
        response = self._client.encrypt(KeyId=self._key_id, Plaintext=data)
        return response['CiphertextBlob']

    def decrypt(self, data: bytes) -> str:
        response = self._client.decrypt(CiphertextBlob=data)
        return response['Plaintext'].decode('utf-8')
