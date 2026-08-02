import os
import datetime
import subprocess

def backup_database():
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_file = f"backups/database/voting_db_{timestamp}.sql"
    db_url = os.getenv("DATABASE_URL", "mysql://root:password@localhost/voting_system")

    try:
        subprocess.run(["mysqldump", "-u", "root", "-p", "voting_system"], stdout=open(backup_file, "w"))
        print(f"Database backup created: {backup_file}")
    except Exception as e:
        print(f"Backup failed: {e}")

if __name__ == "__main__":
    backup_database()
