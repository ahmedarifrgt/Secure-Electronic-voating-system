import json, urllib.request, urllib.error, traceback
url = 'http://127.0.0.1:5000/auth/login'
data = json.dumps({'nid':'11111111'}).encode()
req = urllib.request.Request(url, data=data, headers={'Content-Type':'application/json'})
try:
    with urllib.request.urlopen(req, timeout=5) as r:
        print('STATUS', r.status)
        print(r.read().decode())
except urllib.error.HTTPError as e:
    print('HTTP ERROR', e.code)
    try:
        body = e.read().decode()
        print('BODY:', body)
    except Exception as ex:
        print('Error reading body:', ex)
    traceback.print_exc()
except Exception as e:
    traceback.print_exc()
