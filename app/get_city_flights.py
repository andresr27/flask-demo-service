import os
import requests
from json_logs import log


# The API key can be obtained free at app.goflightlabs.com
apiKey = os.getenv("API_KEY", default="")
apiUrl = f"https://{os.getenv("API_BASE_URL", default="")}"
airport_city = "MVD"


def get_city_flights():
    try:
        url = f"{apiUrl}/flights?access_key={apiKey}&depIata={airport_city}"
    except TypeError as e:
        log.error(e)

    safe_url = f"{apiUrl}flights?access_key=********&depIata={airport_city}"
    response = ""
    try:
        response = requests.get(url)
        response.raise_for_status()
        for flight in response.json()['data']:
            log.info(flight)
    except KeyError:
        log.error(response.json())
    except requests.exceptions.HTTPError:
        log.error(response.json())
        return "Error getting url: " + safe_url
    except requests.exceptions.ConnectionError as e:
        log.error(f"Failed connection to {safe_url}")
        return f"Failed connection to {safe_url}:\n {e}"

    return response.json()