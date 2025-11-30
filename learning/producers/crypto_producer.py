#!/usr/bin/env python3
"""
Crypto Producer - Fetches live cryptocurrency prices from CoinGecko API
and publishes them to Kafka.

This is a production-grade producer with:
- Error handling and retries
- Rate limiting respect
- Structured logging
- Graceful shutdown
"""

import os
import json
import time
import logging
import signal
import sys
from datetime import datetime
from typing import Dict, Any

import requests
from kafka import KafkaProducer
from kafka.errors import KafkaError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration from environment variables
KAFKA_BOOTSTRAP_SERVERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
KAFKA_TOPIC = os.getenv('KAFKA_TOPIC', 'crypto.prices.raw')
API_INTERVAL_SECONDS = int(os.getenv('API_INTERVAL_SECONDS', '30'))
COINGECKO_API_URL = os.getenv('COINGECKO_API_URL', 'https://api.coingecko.com/api/v3')
CRYPTO_IDS = os.getenv('CRYPTO_IDS', 'bitcoin,ethereum').split(',')

# Global flag for graceful shutdown
shutdown_flag = False


def signal_handler(signum, frame):
    """Handle shutdown signals gracefully."""
    global shutdown_flag
    logger.info(f"Received signal {signum}. Shutting down gracefully...")
    shutdown_flag = True


def create_kafka_producer() -> KafkaProducer:
    """Create and return a Kafka producer with retry logic."""
    retries = 5
    for attempt in range(retries):
        try:
            producer = KafkaProducer(
                bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                acks='all',  # Wait for all replicas to acknowledge
                retries=3,
                max_in_flight_requests_per_connection=1  # Ensure ordering
            )
            logger.info(f"✓ Connected to Kafka at {KAFKA_BOOTSTRAP_SERVERS}")
            return producer
        except KafkaError as e:
            logger.error(f"Kafka connection failed (attempt {attempt + 1}/{retries}): {e}")
            if attempt < retries - 1:
                time.sleep(5)
            else:
                raise


def fetch_crypto_prices() -> Dict[str, Any]:
    """
    Fetch cryptocurrency prices from CoinGecko API.
    
    Returns:
        Dict with price data or error information
    """
    try:
        # Build API request
        url = f"{COINGECKO_API_URL}/simple/price"
        params = {
            'ids': ','.join(CRYPTO_IDS),
            'vs_currencies': 'usd',
            'include_market_cap': 'true',
            'include_24hr_vol': 'true',
            'include_24hr_change': 'true',
            'include_last_updated_at': 'true'
        }
        
        logger.debug(f"Calling CoinGecko API: {url}")
        response = requests.get(url, params=params, timeout=10)
        
        # Check for rate limiting
        if response.status_code == 429:
            logger.warning("⚠️ API rate limit hit. Waiting 60 seconds...")
            time.sleep(60)
            return {'error': 'rate_limit', 'retry': True}
        
        response.raise_for_status()
        
        data = response.json()
        logger.info(f"✓ Fetched prices for {len(data)} cryptocurrencies")
        
        return {
            'status': 'success',
            'data': data,
            'api_call_timestamp': datetime.utcnow().isoformat(),
            'http_status_code': response.status_code,
            'source_system': 'coingecko_v3',
            'api_endpoint': '/simple/price'
        }
        
    except requests.exceptions.Timeout:
        logger.error("❌ API request timed out")
        return {'status': 'error', 'error': 'timeout', 'retry': True}
    
    except requests.exceptions.RequestException as e:
        logger.error(f"❌ API request failed: {e}")
        return {'status': 'error', 'error': str(e), 'retry': False}
    
    except json.JSONDecodeError as e:
        logger.error(f"❌ Invalid JSON response: {e}")
        return {'status': 'error', 'error': 'invalid_json', 'retry': False}


def publish_to_kafka(producer: KafkaProducer, data: Dict[str, Any]) -> bool:
    """
    Publish data to Kafka topic.
    
    Args:
        producer: Kafka producer instance
        data: Data to publish
        
    Returns:
        True if successful, False otherwise
    """
    try:
        # Add ingestion timestamp
        payload = {
            **data,
            'ingestion_timestamp': datetime.utcnow().isoformat()
        }
        
        # Send to Kafka
        future = producer.send(KAFKA_TOPIC, value=payload)
        
        # Wait for confirmation (with timeout)
        record_metadata = future.get(timeout=10)
        
        logger.info(
            f"✓ Published to Kafka: topic={record_metadata.topic}, "
            f"partition={record_metadata.partition}, offset={record_metadata.offset}"
        )
        return True
        
    except KafkaError as e:
        logger.error(f"❌ Failed to publish to Kafka: {e}")
        return False


def main():
    """Main producer loop."""
    global shutdown_flag
    
    # Register signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    logger.info("=" * 70)
    logger.info("Crypto Price Producer Starting")
    logger.info("=" * 70)
    logger.info(f"Kafka Brokers: {KAFKA_BOOTSTRAP_SERVERS}")
    logger.info(f"Kafka Topic: {KAFKA_TOPIC}")
    logger.info(f"API Interval: {API_INTERVAL_SECONDS} seconds")
    logger.info(f"Tracking Cryptos: {', '.join(CRYPTO_IDS)}")
    logger.info("=" * 70)
    
    # Create Kafka producer
    try:
        producer = create_kafka_producer()
    except Exception as e:
        logger.critical(f"Failed to create Kafka producer: {e}")
        sys.exit(1)
    
    # Main loop
    try:
        iteration = 0
        while not shutdown_flag:
            iteration += 1
            logger.info(f"\n{'='*70}")
            logger.info(f"Iteration #{iteration} - {datetime.utcnow().isoformat()}")
            logger.info(f"{'='*70}")
            
            # Fetch prices
            result = fetch_crypto_prices()
            
            # Handle errors
            if result.get('status') == 'error':
                if result.get('retry'):
                    logger.warning("Retrying in next iteration...")
                else:
                    logger.error("Non-retriable error. Skipping this iteration.")
            else:
                # Publish to Kafka
                success = publish_to_kafka(producer, result)
                if not success:
                    logger.warning("Failed to publish to Kafka. Will retry next iteration.")
            
            # Wait for next iteration
            if not shutdown_flag:
                logger.info(f"⏸️  Waiting {API_INTERVAL_SECONDS} seconds...")
                time.sleep(API_INTERVAL_SECONDS)
    
    except Exception as e:
        logger.critical(f"Unexpected error in main loop: {e}", exc_info=True)
    
    finally:
        # Cleanup
        logger.info("\n" + "=" * 70)
        logger.info("Shutting down producer...")
        producer.flush()  # Ensure all messages are sent
        producer.close()
        logger.info("✓ Producer shut down cleanly")
        logger.info("=" * 70)


if __name__ == '__main__':
    main()
