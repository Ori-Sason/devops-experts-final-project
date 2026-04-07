import sqlite3
from db.init import get_db


def increment_visit(page_path):
    conn = get_db()
    try:
        with conn:
            cursor = conn.cursor()
            
            cursor.execute("SELECT count FROM visits WHERE path = ?", (page_path,))
            row = cursor.fetchone()

            if row:
                cursor.execute("UPDATE visits SET count = count + 1 WHERE path = ?", (page_path,))
            else:
                cursor.execute("INSERT INTO visits (path, count) VALUES (?, 1)", (page_path,))

    except sqlite3.Error as e:
        print(f"Database error on increment_visit:\n")
        print(f" {e}:\n")
    
    finally:
        conn.close()