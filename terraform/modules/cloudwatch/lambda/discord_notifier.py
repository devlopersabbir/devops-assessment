"""Forward AWS CloudWatch Alarm SNS notifications to a Discord webhook."""

import json
import logging
import os
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

logger = logging.getLogger()
logger.setLevel(logging.INFO)

STATE_STYLES = {
    "ALARM": {"color": 15158332, "emoji": "\U0001f6a8"},
    "OK": {"color": 3066993, "emoji": "\u2705"},
    "INSUFFICIENT_DATA": {"color": 15105570, "emoji": "\u26a0\ufe0f"},
}


def _build_alarm_embed(alarm: dict[str, Any], project: str, environment: str) -> dict[str, Any]:
    state = alarm.get("NewStateValue", "UNKNOWN")
    old_state = alarm.get("OldStateValue", "UNKNOWN")
    style = STATE_STYLES.get(state, {"color": 9807270, "emoji": "\u2139\ufe0f"})

    alarm_name = alarm.get("AlarmName", "Unnamed Alarm")
    description = alarm.get("AlarmDescription") or "No description provided."
    reason = alarm.get("NewStateReason", "No reason provided.")
    timestamp = alarm.get("StateChangeTime", "")
    region = alarm.get("Region", os.environ.get("AWS_REGION", ""))

    trigger = alarm.get("Trigger", {})
    namespace = trigger.get("Namespace", "N/A")
    metric_name = trigger.get("MetricName", "N/A")
    threshold = trigger.get("Threshold", "N/A")
    operator = trigger.get("ComparisonOperator", "")

    region_code = os.environ.get("AWS_REGION", "ap-south-1")
    alarm_url = (
        f"https://{region_code}.console.aws.amazon.com/cloudwatch/home"
        f"?region={region_code}#alarmsV2:alarm/{urllib.parse.quote(alarm_name, safe='')}"
    )

    fields = [
        {"name": "Environment", "value": f"`{project}-{environment}`", "inline": True},
        {"name": "Transition", "value": f"`{old_state}` -> `{state}`", "inline": True},
        {"name": "Region", "value": f"`{region}`", "inline": True},
        {"name": "Metric", "value": f"`{namespace} / {metric_name}`", "inline": True},
        {"name": "Condition", "value": f"`{operator} {threshold}`".strip(), "inline": True},
        {"name": "Reason", "value": reason[:1024], "inline": False},
    ]

    embed: dict[str, Any] = {
        "title": f"{style['emoji']} [{state}] {alarm_name}",
        "url": alarm_url,
        "description": description[:2048],
        "color": style["color"],
        "fields": fields,
        "footer": {"text": "AWS CloudWatch Alarms"},
    }
    if timestamp:
        embed["timestamp"] = timestamp
    return embed


def _post_discord(webhook_url: str, payload: dict[str, Any]) -> None:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        webhook_url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "aws-cloudwatch-sns-discord-notifier/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            logger.info("Discord webhook responded with status %s", resp.status)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        logger.error("Discord webhook HTTP error %s: %s", exc.code, body)
        raise


def lambda_handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    webhook_url = os.environ.get("DISCORD_WEBHOOK_URL", "").strip()
    if not webhook_url:
        logger.warning("DISCORD_WEBHOOK_URL is not configured; skipping notification.")
        return {"statusCode": 200, "body": "skipped"}

    project = os.environ.get("PROJECT_NAME", "app")
    environment = os.environ.get("ENVIRONMENT", "staging")

    records = event.get("Records", [])
    for record in records:
        sns = record.get("Sns", {})
        raw_message = sns.get("Message", "")
        subject = sns.get("Subject", "AWS SNS Notification")

        try:
            parsed = json.loads(raw_message)
        except (json.JSONDecodeError, TypeError):
            parsed = None

        if isinstance(parsed, dict) and "AlarmName" in parsed:
            embed = _build_alarm_embed(parsed, project, environment)
        else:
            embed = {
                "title": f"\u2139\ufe0f {subject[:250]}",
                "description": str(raw_message)[:2048] or "Empty SNS message",
                "color": 3447003,
                "footer": {"text": f"{project}-{environment} SNS"},
            }

        _post_discord(webhook_url, {"embeds": [embed]})

    return {"statusCode": 200, "processed": len(records)}
