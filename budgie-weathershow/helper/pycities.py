# helper app to convert openweather cities json dump to a flat file format
# take the city.list.json (uncompress the file) from
# http://bulk.openweathermap.org/sample/

import json
import math


# really truncate floats rather than rounding
def truncate(number, digits) -> float:
    stepper = 10.0 ** digits
    return math.trunc(stepper * number) / stepper


states = {}

# load the json file from openweather
with open('city.list.json') as f:
    data = json.load(f)

# load a json file with US states mapping to real names
# save into a dict to be used for searching later
with open('states.json') as s:
    statesjson = json.load(s)
    for element in statesjson:
        states[element['abbreviation']] = element['name']

duplicates = {}

# open a file called cities for writing
with open('cities', 'w') as f:
    for element in data:

        state = ""
        country = element['country']
        if country == "US":
            if element['state'] == '00':  # United States
                continue  # odd data in dump to ignore

            if element['state'] != '':
                state = ", " + states[element['state']]
                # for US places we also include the state name
                # which we have to search via its abbreviation

        name = element['name']
        keycheck = name + state + ", " + country
        line = str(element['id']) + " " + keycheck + "\n"

        # the city file potentially has lots of duplicates
        # filter these out - we are looking for
        # places that are very close geographically

        if keycheck in duplicates:
            coord = duplicates[keycheck]
            lat = truncate(coord['lat'], 1)
            lon = truncate(coord['lon'], 1)

            comparelat = truncate(element['coord']['lat'], 1)
            comparelon = truncate(element['coord']['lon'], 1)

            if lat == comparelat and lon == comparelon:
                # the saved keycheck is the same in terms of lat,
                # lon (1 decimal place)
                continue
        else:
            duplicates[keycheck] = element['coord']

        f.write(line)
