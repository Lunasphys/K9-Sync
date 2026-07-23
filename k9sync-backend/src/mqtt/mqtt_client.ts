import mqtt, { MqttClient } from 'mqtt';
import { logger } from '../shared/logger.js';
import { handleGpsMessage, handleHealthMessage } from './mqtt_collar_handler.js';

const TOPIC_GPS = 'k9sync/collar/+/gps';
const TOPIC_HEALTH = 'k9sync/collar/+/health';

export interface MqttConnectOptions {
  username?: string;
  password?: string;
}

export function connectMqtt(brokerUrl: string, opts: MqttConnectOptions = {}): MqttClient {
  const client = mqtt.connect(brokerUrl, {
    username: opts.username || undefined,
    password: opts.password || undefined,
    reconnectPeriod: 5000,
  });

  client.on('connect', () => {
    logger.info({ brokerUrl }, 'MQTT connected');
    client.subscribe([TOPIC_GPS, TOPIC_HEALTH], { qos: 1 }, (err) => {
      if (err) {
        logger.error({ err }, 'MQTT subscribe failed');
      } else {
        logger.info({ topics: [TOPIC_GPS, TOPIC_HEALTH] }, 'MQTT subscribed');
      }
    });
  });

  client.on('reconnect', () => logger.warn('MQTT reconnecting'));
  client.on('close', () => logger.warn('MQTT connection closed'));
  client.on('error', (err) => logger.error({ err }, 'MQTT client error'));

  client.on('message', (topic, payload) => {
    routeMessage(topic, payload).catch((err) => {
      logger.error({ err, topic }, 'MQTT message handling failed — dropped');
    });
  });

  return client;
}

async function routeMessage(topic: string, payload: Buffer): Promise<void> {
  // k9sync/collar/{serial}/gps|health
  const parts = topic.split('/');
  if (parts.length !== 4 || parts[0] !== 'k9sync' || parts[1] !== 'collar') {
    logger.warn({ topic }, 'Ignoring message on unexpected MQTT topic');
    return;
  }
  const [, , serial, kind] = parts;

  let json: unknown;
  try {
    json = JSON.parse(payload.toString('utf8'));
  } catch (err) {
    logger.warn({ topic, err }, 'Malformed MQTT payload (invalid JSON) — dropped');
    return;
  }

  if (kind === 'gps') {
    await handleGpsMessage(serial, json);
  } else if (kind === 'health') {
    await handleHealthMessage(serial, json);
  } else {
    logger.debug({ topic }, 'Unhandled collar MQTT topic kind');
  }
}
