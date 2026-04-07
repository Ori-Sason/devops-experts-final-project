import os
import sqlite3

def create_database_and_tables(db_filename):
    conn = sqlite3.connect(db_filename)

    ddl = """
        CREATE TABLE visits (
            id INTEGER NOT NULL PRIMARY KEY,
            path TEXT NOT NULL UNIQUE,
            count INTEGER NOT NULL
        );
    """

    conn.executescript(ddl)

    return conn

def get_db() -> sqlite3.Connection:
    db_filename = './db/main.db'
    if not os.path.exists(db_filename):
        conn = create_database_and_tables(db_filename)
    else:
        conn = sqlite3.connect(db_filename)
    
    return conn
