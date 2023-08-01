import boto3


def handler(event, context):
    instance_id = event['detail']['instance-id']
    ec2 = boto3.client('ec2')

    response = ec2.stop_instances(InstanceIds=[instance_id])

    return response
