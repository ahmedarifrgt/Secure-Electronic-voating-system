from backend.app import create_app

app = create_app()
client = app.test_client()
resp = client.post('/auth/login', json={'username': 'admin', 'password': 'Admin@123'})
print(resp.status_code)
print(resp.get_json())
