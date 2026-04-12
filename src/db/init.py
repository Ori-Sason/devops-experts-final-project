import psycopg2
from psycopg2 import sql
from psycopg2.extras import RealDictCursor

conn = psycopg2.connect(
    host="db",
    database="postgres",
    user="postgres",
    password="password"
)

def get_connection():
    return conn

def get_cursor():
    return conn.cursor(cursor_factory=RealDictCursor)


def create_database_and_tables():
    if not _is_table_exists('visits'):
        ddl = """
            CREATE TABLE visits (
                id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
                path TEXT NOT NULL UNIQUE,
                count INTEGER NOT NULL
            );
        """

        cursor = get_cursor()
        cursor.execute(ddl)
        conn.commit()
        cursor.close()


def _is_table_exists(table_name):
    cursor = get_cursor()

    query = sql.SQL("""
        SELECT EXISTS(
            SELECT table_name
            FROM information_schema.tables
            WHERE table_name={table_name}
        );
        """).format(table_name=sql.Literal(table_name))

    cursor.execute(query)
    res = cursor.fetchone()
    cursor.close()
    
    return res['exists'] is True


create_database_and_tables()