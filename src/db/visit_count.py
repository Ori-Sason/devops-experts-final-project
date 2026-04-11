import sqlite3
from db.init import get_db


def increment_visit(page_path):
    try:
        with get_db() as conn:
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

def get_visits():
    try:
        with get_db() as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            
            query = """
                SELECT path, count
                FROM visits
                ORDER BY count DESC
            """
            
            cursor.execute(query)
            rows = cursor.fetchall()
            visits = [dict(row) for row in rows]
            
            return visits

    
    except sqlite3.Error as e:
        print(f"Database error on get_visits:\n")
        print(f" {e}:\n")
    
    finally:
        conn.close()
