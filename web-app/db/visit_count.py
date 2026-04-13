import psycopg2
from psycopg2 import sql
from db.init import get_connection, get_cursor


def increment_visit(page_path):
    try:
        with get_connection() as conn:
            cursor = get_cursor()
            query = sql.SQL("SELECT count FROM visits WHERE path = {page_path}").format(page_path=sql.Literal(page_path))
            cursor.execute(query)
            row = cursor.fetchone()

            if row:
                query = sql.SQL("UPDATE visits SET count = count + 1 WHERE path = {page_path}").format(page_path=sql.Literal(page_path))
                cursor.execute(query)
                conn.commit()
            else:
                query = sql.SQL("INSERT INTO visits (path, count) VALUES ({page_path}, 1)").format(page_path=sql.Literal(page_path))
                cursor.execute(query)
                conn.commit()

    except psycopg2.Error as e:
        print(f"Database error on increment_visit:\n")
        print(f" {e}:\n")

def get_visits():
    try:
        with get_connection() as conn:
            cursor = get_cursor()
            
            query = """
                SELECT path, count
                FROM visits
                ORDER BY count DESC
            """
            
            cursor.execute(query)
            rows = cursor.fetchall()
            visits = [dict(row) for row in rows]
            
            return visits

    
    except psycopg2.Error as e:
        print(f"Database error on get_visits:\n")
        print(f" {e}:\n")
