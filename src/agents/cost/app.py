"""Cost agent Lambda handler - Cost Explorer + Bedrock; returns cost/optimization report."""

import json


def handler(event, context):
    """Lambda entrypoint. Returns cost report stub."""
    # TODO: Cost Explorer + Bedrock; return cost/optimization report
    return {
        "statusCode": 200,
        "body": json.dumps({"status": "ok", "report": "Cost report placeholder"}),
    }
