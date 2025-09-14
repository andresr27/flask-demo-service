def get_city_flights():
    airport_city = "MVD"
    try:
        url = apiUrl + f"flights?access_key=" + apiKey + f"&depIata=" + airport_city
    except TypeError as e:
        log.error(e)

    safe_url = apiUrl + f"flights?access_key=" + "#####" + f"&depIata=" + airport_city
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
        return "Error getting url:" + safe_url

    return response.json()