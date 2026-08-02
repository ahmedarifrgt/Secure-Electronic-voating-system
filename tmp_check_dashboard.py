import urllib.request
url = 'http://127.0.0.1:5000/dashboard/stats'
req = urllib.request.Request(url, headers={'Content-Type': 'application/json'})
try:
    with urllib.request.urlopen(req) as resp:
        print(resp.status)
        print(resp.read().decode())
except Exception as e:
    print('ERROR', e)
