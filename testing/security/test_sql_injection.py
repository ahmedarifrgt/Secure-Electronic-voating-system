def test_sql_injection(client):
    malicious_input = "' OR '1'='1"
    response = client.post("/auth/login", json={"nid": malicious_input, "live_image_path": "test.jpg"})
    assert response.status_code == 401
