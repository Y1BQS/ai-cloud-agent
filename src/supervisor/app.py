"""Supervisor Lambda handler - orchestrates subordinate agents and sends email reports."""

import json
import os


def handler(event, context):
    """
    Lambda entrypoint. Event should include schedule_type: "daily" or "weekly".
    """
    schedule_type = event.get("schedule_type", "daily")
    # TODO: invoke cost/security agents, call Bedrock, send SES email
    return {
        "statusCode": 200,
        "body": json.dumps({"schedule_type": schedule_type, "status": "ok"}),
    }
