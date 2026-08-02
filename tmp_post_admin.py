import urllib.request, json
url = 'http://127.0.0.1:5000/auth/login'
data = json.dumps({'username':'admin','password':'Admin@123'}).encode('utf-8')
req = urllib.request.Request(url, data=data, headers={'Content-Type':'application/json'})
with urllib.request.urlopen(req) as resp:
    print(resp.status)
    print(resp.read().decode())
