from prometheus_client import start_http_server, Summary, Counter, Gauge, Histogram, generate_latest
import time
import random

# Counter: A cumulative metric that only ever increases.
REQUEST_COUNT = Counter('app_requests_total', 'Total number of app requests.')

# Gauge: A metric that represents a single numerical value that can arbitrarily go up and down.
IN_PROGRESS_REQUESTS = Gauge('app_in_progress_requests', 'Number of requests currently being processed.')

# Summary: Observes individual observations and provides quantiles.
REQUEST_LATENCY = Summary('app_request_latency_seconds', 'Latency of app requests in seconds.')

# Histogram: Observes individual observations and provides configurable buckets.
REQUEST_DURATION_HISTOGRAM = Histogram('app_request_duration_seconds_bucket', 'Histogram of request durations.')

request_count = Counter(
    'flask_requests_total',
    'Total HTTP requests to the Flask app',
    ['method', 'endpoint']
)


@REQUEST_LATENCY.time()  # Decorator for measuring function execution time with a Summary
def process_data():
    IN_PROGRESS_REQUESTS.inc()  # Increment gauge
    REQUEST_COUNT.inc()  # Increment counter
    time.sleep(random.uniform(0.1, 0.5))  # Simulate work
    REQUEST_DURATION_HISTOGRAM.observe(random.uniform(0.1, 0.5))  # Observe value for histogram
    IN_PROGRESS_REQUESTS.dec()  # Decrement gauge


def start_server():
    start_http_server(8000)

def get_latest():
    return generate_latest()