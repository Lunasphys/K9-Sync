#!/usr/bin/env python3
"""K9 Sync - ESP32 collar simulator for Flutter development and testing."""

import json
import time
import math
import random
import argparse
from datetime import datetime, timezone
import paho.mqtt.client as mqtt

BROKER = "127.0.0.1"
PORT = 1883
SERIAL = "SIM001"

BASE_LAT, BASE_LNG = 45.7578, 4.8320


def topic(t):
    return f"k9sync/collar/{SERIAL}/{t}"


TOPIC_GPS = topic("gps")
TOPIC_HEALTH = topic("health")
TOPIC_ACTIVITY = topic("activity")
TOPIC_STATUS = topic("status")
TOPIC_ALERT = topic("alert")


def simulate_walk(step):
    """Simulate a walk in a growing spiral around the base position."""
    angle = step * 0.1
    radius = 0.001 + step * 0.00003
    lat = BASE_LAT + radius * math.sin(angle)
    lng = BASE_LNG + radius * math.cos(angle)
    noise = random.uniform(-0.00005, 0.00005)
    return lat + noise, lng + noise


class HealthSimulator:
    def __init__(self):
        self.steps = 0
        self.anomaly_counter = 0

    def get_health(self, step):
        is_running = (step % 20 < 10)
        hr_base = 120 if is_running else 75
        hr = hr_base + random.randint(-8, 8)
        temp = 38.3 + random.uniform(-0.3, 0.4)

        self.anomaly_counter += 1
        anomaly = None
        if self.anomaly_counter % 50 == 0:
            hr = random.choice([35, 220])
            anomaly = "heart_rate_critical"

        self.steps += random.randint(8, 15) if is_running else random.randint(0, 3)

        return {
            "heartRate": hr,
            "temperature": round(temp, 2),
            "steps": self.steps,
            "activeMinutes": step // 20 if is_running else 0,
            "anomalyDetected": anomaly is not None,
            "anomalyType": anomaly or "none",
        }


def run(dog_id, duration, interval):
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=f"simulator_{SERIAL}")

    connected = False

    def on_connect(c, userdata, flags, reason_code, properties):
        nonlocal connected
        if reason_code == 0:
            connected = True
            print(f"[K9 Sync Simulator] Connected to broker {BROKER}:{PORT}")
        else:
            print(f"[K9 Sync Simulator] Connection failed: reason_code={reason_code}")

    client.on_connect = on_connect
    client.connect(BROKER, PORT, keepalive=60)
    client.loop_start()

    # Wait for connection (max 5s)
    for _ in range(50):
        if connected:
            break
        time.sleep(0.1)

    if not connected:
        print("[K9 Sync Simulator] ERROR: Could not connect to broker. Is Mosquitto running?")
        return

    health = HealthSimulator()
    step = 0
    start = time.time()

    print(f"[K9 Sync Simulator] Starting — collar={SERIAL} dog={dog_id}")
    print(f"[K9 Sync Simulator] GPS topic : {TOPIC_GPS}")
    print(f"[K9 Sync Simulator] Health topic : {TOPIC_HEALTH}")

    # Publish initial status
    client.publish(TOPIC_STATUS, json.dumps({
        "serial": SERIAL,
        "dogId": dog_id,
        "batteryLevel": 87,
        "firmwareVersion": "1.0.0-sim",
        "isOnline": True,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }), qos=1, retain=True)

    while time.time() - start < duration:
        ts = datetime.now(timezone.utc).isoformat()
        lat, lng = simulate_walk(step)
        h = health.get_health(step)

        gps_payload = {
            "collarSerial": SERIAL,
            "dogId": dog_id,
            "latitude": round(lat, 7),
            "longitude": round(lng, 7),
            "accuracy": round(random.uniform(2.5, 8.0), 2),
            "recordedAt": ts,
        }
        client.publish(TOPIC_GPS, json.dumps(gps_payload), qos=1)

        health_payload = {
            "collarSerial": SERIAL,
            "dogId": dog_id,
            **h,
            "recordedAt": ts,
        }
        client.publish(TOPIC_HEALTH, json.dumps(health_payload), qos=1)

        if h["anomalyDetected"]:
            alert_payload = {
                "collarSerial": SERIAL,
                "dogId": dog_id,
                "type": h["anomalyType"],
                "message": f"Anomaly detected: {h['anomalyType']} — HR={h['heartRate']}bpm",
                "severity": "high",
                "triggeredAt": ts,
            }
            client.publish(TOPIC_ALERT, json.dumps(alert_payload), qos=2)
            print(f"[ALERT] {h['anomalyType']} — HR={h['heartRate']}bpm")

        print(f"[Step {step:04d}] GPS=({lat:.5f},{lng:.5f}) HR={h['heartRate']}bpm Steps={h['steps']}")

        step += 1
        time.sleep(interval)

    client.loop_stop()
    client.disconnect()
    print("[K9 Sync Simulator] Done.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="K9 Sync collar simulator")
    parser.add_argument("--dog-id", required=True, help="Dog UUID")
    parser.add_argument("--duration", type=int, default=3600, help="Duration in seconds")
    parser.add_argument("--interval", type=int, default=3, help="Publish interval in seconds")
    args = parser.parse_args()

    run(args.dog_id, args.duration, args.interval)
