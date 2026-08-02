import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv(dotenv_path=os.path.join(os.getcwd(), '.env'))
url = os.getenv('DATABASE_URL', 'mysql+pymysql://root:password@localhost/voting_system')
print('DATABASE_URL=', url)
engine = create_engine(url)
with engine.connect() as conn:
    print('TABLES:', [row[0] for row in conn.execute(text('SHOW TABLES'))])
    cols = conn.execute(text('SHOW COLUMNS FROM voters')).fetchall()
    print('COLUMNS:')
    for row in cols:
        print(tuple(row))
