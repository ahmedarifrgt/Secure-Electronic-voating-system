import time

def test_vote_throughput(client):
    start = time.time()
    for i in range(1000):
        client.post("/vote/cast", json={
            "voter_id": i,
            "election_id": 1,
            "candidate_id": 2
        })
    end = time.time()
    duration = end - start
    votes_per_minute = (1000 / duration) * 60
    assert votes_per_minute > 500  # Example threshold
