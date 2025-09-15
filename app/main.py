import os
import requests
from flask import Flask
from json_logs import log
from get_city_flights import get_city_flights
import logging

# Need to stop Flask logging or change it to Json
app = Flask(__name__)
app.logger.disabled = True
app = Flask(__name__)
app_logger = logging.getLogger('werkzeug')
app_logger.disabled = True

@app.route("/liveness")
def liveness():
    return "UP"


# Test if we can connect to the endpoint to accept requests
@app.route("/readyness")
def readiness():
    try:
        requests.get(apiUrl)
    except Exception as e:
        log.error(e)
        return "DOWN"
    return "UP"


# Sample app, it just returns
@app.route("/")
def checks():
    # Working in a more generic endpoint check
    return get_city_flights()


if __name__ == "__main__":
    app.run(host='0.0.0.0')
