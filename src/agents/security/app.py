"""Security agent Lambda handler - Security Hub, EC2, S3 + Bedrock; returns security report."""

import json


def handler(event, context):
    """Lambda entrypoint. Returns security report stub."""
    # TODO: Security Hub, EC2, S3 + Bedrock; return security report
    return {
        "statusCode": 200,
        "body": json.dumps({"status": "ok", "report": "Security report placeholder"}),
    }
