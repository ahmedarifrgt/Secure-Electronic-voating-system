import json, urllib.request
url = 'http://127.0.0.1:5000/auth/login'
data = json.dumps({'nid':'11111111'}).encode()
req = urllib.request.Request(url, data=data, headers={'Content-Type':'application/json'})
try:
    with urllib.request.urlopen(req, timeout=5) as r:
        print('STATUS', r.status)
        print(r.read().decode())
except Exception as e:
    # print full exception
    import traceback
    traceback.print_exc()
