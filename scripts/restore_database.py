import os
import subprocess

def restore_database(backup_file):
    try:
        subprocess.run(["mysql", "-u", "root", "-p", "voting_system"], stdin=open(backup_file))
        print(f"Database restored from {backup_file}")
    except Exception as e:
        print(f"Restore failed: {e}")

if __name__ == "__main__":
    restore_database("backups/database/voting_db_latest.sql")
