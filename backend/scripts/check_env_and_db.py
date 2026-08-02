import os, sys
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
import urllib.request

load_dotenv(dotenv_path=os.path.join(os.getcwd(), '.env'))
url = os.getenv('DATABASE_URL')
print('LOADED DATABASE_URL=', url)

# Test SQLAlchemy connection using DATABASE_URL
if not url:
    print('No DATABASE_URL found in .env')
    sys.exit(1)

try:
    engine = create_engine(url)
    with engine.connect() as conn:
        # list tables
        tables = [row[0] for row in conn.execute(text('SHOW TABLES'))]
        print('TABLES:', tables)
        try:
            total = conn.execute(text('SELECT COUNT(*) FROM voters')).scalar()
            print('VOTERS COUNT (via SQLAlchemy):', total)
        except Exception as e:
            print('Error querying voters table via SQLAlchemy:', e)
except Exception as e:
    print('SQLAlchemy connection error:', e)

# Test HTTP endpoint
try:
    with urllib.request.urlopen('http://127.0.0.1:5000/dashboard/stats', timeout=5) as r:
        print('HTTP /dashboard/stats status:', r.status)
        print(r.read().decode())
except Exception as e:
    print('HTTP request error:', e)
