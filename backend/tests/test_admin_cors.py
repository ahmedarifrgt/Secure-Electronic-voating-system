from backend.app import create_app


def test_admin_election_and_candidate_routes_support_cors_preflight():
    app = create_app()

    with app.test_client() as client:
        headers = {
            "Origin": "http://localhost:8825",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization,content-type,accept",
        }

        election_resp = client.options("/election/create", headers=headers)
        assert election_resp.status_code in (200, 204)
        assert election_resp.headers.get("Access-Control-Allow-Origin") == "http://localhost:8825"
        allow_headers = election_resp.headers.get("Access-Control-Allow-Headers", "")
        assert "Authorization" in allow_headers or "authorization" in allow_headers

        candidate_resp = client.options("/candidate/add", headers=headers)
        assert candidate_resp.status_code in (200, 204)
        assert candidate_resp.headers.get("Access-Control-Allow-Origin") == "http://localhost:8825"
        allow_headers = candidate_resp.headers.get("Access-Control-Allow-Headers", "")
        assert "Authorization" in allow_headers or "authorization" in allow_headers
