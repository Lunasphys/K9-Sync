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
DEFAULT_SERIAL = "SIM001"

BASE_LAT, BASE_LNG = 45.7578, 4.8320


def topic(serial, t):
    return f"k9sync/collar/{serial}/{t}"


EARTH_RADIUS_M = 6371000.0


def _meters_per_degree_lat():
    return 111320.0


def _meters_per_degree_lng(lat_deg):
    return 111320.0 * math.cos(math.radians(lat_deg))


def _haversine_m(lat1, lng1, lat2, lng2):
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2) ** 2
    return 2 * EARTH_RADIUS_M * math.asin(math.sqrt(a))


def _bearing_to(lat, lng, target_lat, target_lng):
    """Compass bearing in degrees from (lat, lng) to (target_lat, target_lng)."""
    dlng = math.radians(target_lng - lng)
    lat1 = math.radians(lat)
    lat2 = math.radians(target_lat)
    y = math.sin(dlng) * math.cos(lat2)
    x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dlng)
    return math.degrees(math.atan2(y, x)) % 360


def _shortest_angle_diff(a, b):
    """Smallest signed delta from angle a to angle b, in degrees, within [-180, 180]."""
    return (b - a + 180) % 360 - 180


class WalkSimulator:
    """Moves the collar at a believable dog-walking pace instead of an
    unbounded spiral. The distance covered between two consecutive GPS
    points is derived from a real speed (km/h) and the actual publish
    interval — so changing --interval keeps the same walking pace instead
    of changing how "fast" the dog looks, which is what made the old
    spiral (whose radius grew with the step count, not with elapsed time)
    look like it was accelerating into a sprint.
    """

    # Loosely-leashed dog walk pace — comfortably below a jog (~8+ km/h).
    BASE_SPEED_KMH = 4.5
    MAX_TURN_DEG = 18.0  # how sharply the dog can change heading per step
    WANDER_RADIUS_M = 300.0  # beyond this, gently curve back toward base
    GPS_NOISE_M = 0.8  # small receiver jitter, well under a real walking step

    def __init__(self, speed_multiplier=1.0):
        self.lat = BASE_LAT
        self.lng = BASE_LNG
        self.heading = random.uniform(0, 360)
        self.speed_mps = (self.BASE_SPEED_KMH * speed_multiplier) * 1000 / 3600

    def step(self, interval_s):
        turn = random.uniform(-self.MAX_TURN_DEG, self.MAX_TURN_DEG)

        dist_from_base = _haversine_m(self.lat, self.lng, BASE_LAT, BASE_LNG)
        if dist_from_base > self.WANDER_RADIUS_M:
            bearing_home = _bearing_to(self.lat, self.lng, BASE_LAT, BASE_LNG)
            turn += _shortest_angle_diff(self.heading, bearing_home) * 0.35

        self.heading = (self.heading + turn) % 360

        distance_m = self.speed_mps * interval_s
        heading_rad = math.radians(self.heading)
        dlat = (distance_m * math.cos(heading_rad)) / _meters_per_degree_lat()
        dlng = (distance_m * math.sin(heading_rad)) / _meters_per_degree_lng(self.lat)

        self.lat += dlat
        self.lng += dlng

        # Tiny GPS jitter on top of the real step — realistic receiver
        # noise, not the dominant motion (the old code's +/-0.00005 deg
        # noise was ~5.5m, comparable to or bigger than a whole step).
        noise_lat = random.uniform(-self.GPS_NOISE_M, self.GPS_NOISE_M) / _meters_per_degree_lat()
        noise_lng = (
            random.uniform(-self.GPS_NOISE_M, self.GPS_NOISE_M) / _meters_per_degree_lng(self.lat)
        )

        return self.lat + noise_lat, self.lng + noise_lng


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

        # Synthetic sleep phase for demo purposes — a dog can't be asleep
        # while running; during rest steps, cycle awake -> light -> deep so
        # the sleep breakdown screen has some real variety to show.
        if is_running:
            sleep_phase = "awake"
        else:
            rest_step = step % 20
            if rest_step < 13:
                sleep_phase = "awake"
            elif rest_step < 17:
                sleep_phase = "light"
            else:
                sleep_phase = "deep"

        return {
            "heartRate": hr,
            "temperature": round(temp, 2),
            "steps": self.steps,
            "activeMinutes": step // 20 if is_running else 0,
            "sleepPhase": sleep_phase,
            "anomalyDetected": anomaly is not None,
            "anomalyType": anomaly or "none",
        }


def run(dog_id, duration, interval, speed_multiplier, serial=DEFAULT_SERIAL):
    topic_gps = topic(serial, "gps")
    topic_health = topic(serial, "health")
    topic_status = topic(serial, "status")
    topic_alert = topic(serial, "alert")

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=f"simulator_{serial}")

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
    walker = WalkSimulator(speed_multiplier=speed_multiplier)
    step = 0
    start = time.time()

    effective_kmh = WalkSimulator.BASE_SPEED_KMH * speed_multiplier
    step_distance_m = walker.speed_mps * interval
    print(f"[K9 Sync Simulator] Starting — collar={serial} dog={dog_id}")
    print(f"[K9 Sync Simulator] GPS topic : {topic_gps}")
    print(f"[K9 Sync Simulator] Health topic : {topic_health}")
    print(
        f"[K9 Sync Simulator] Walking pace: {effective_kmh:.1f} km/h "
        f"(~{step_distance_m:.1f}m every {interval}s)"
    )

    # Publish initial status
    client.publish(topic_status, json.dumps({
        "serial": serial,
        "dogId": dog_id,
        "batteryLevel": 87,
        "firmwareVersion": "1.0.0-sim",
        "isOnline": True,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }), qos=1, retain=True)

    while time.time() - start < duration:
        ts = datetime.now(timezone.utc).isoformat()
        lat, lng = walker.step(interval)
        h = health.get_health(step)

        gps_payload = {
            "collarSerial": serial,
            "dogId": dog_id,
            "latitude": round(lat, 7),
            "longitude": round(lng, 7),
            "accuracy": round(random.uniform(2.5, 8.0), 2),
            "recordedAt": ts,
        }
        client.publish(topic_gps, json.dumps(gps_payload), qos=1)

        health_payload = {
            "collarSerial": serial,
            "dogId": dog_id,
            **h,
            "recordedAt": ts,
        }
        client.publish(topic_health, json.dumps(health_payload), qos=1)

        if h["anomalyDetected"]:
            alert_payload = {
                "collarSerial": serial,
                "dogId": dog_id,
                "type": h["anomalyType"],
                "message": f"Anomaly detected: {h['anomalyType']} — HR={h['heartRate']}bpm",
                "severity": "high",
                "triggeredAt": ts,
            }
            client.publish(topic_alert, json.dumps(alert_payload), qos=2)
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
    parser.add_argument(
        "--serial",
        default=DEFAULT_SERIAL,
        help=(
            f"Collar serial number (default {DEFAULT_SERIAL}). Use a different "
            "value (e.g. SIM002) to run a second instance for another dog "
            "paired to that serial — each serial needs its own simulator "
            "process publishing to its own MQTT topic."
        ),
    )
    parser.add_argument(
        "--speed-multiplier",
        type=float,
        default=1.0,
        help=(
            "Scales the walking pace (default ~4.5 km/h). "
            "E.g. 2.0 for a brisker walk on a shorter demo, without looking artificial."
        ),
    )
    args = parser.parse_args()

    run(args.dog_id, args.duration, args.interval, args.speed_multiplier, args.serial)
