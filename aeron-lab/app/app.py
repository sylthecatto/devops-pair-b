from flask import Flask, render_template, request, redirect, url_for, jsonify
import os
import psycopg2
import sqlite3
from datetime import datetime

app = Flask(__name__)

DB_HOST = os.getenv("DB_HOST", "db-node-1")
DB_NAME = os.getenv("DB_NAME", "aeron_db")
DB_USER = os.getenv("DB_USER", "dbuser")
DB_PASS = os.getenv("DB_PASS", "dbpassword123")
DB_PORT = int(os.getenv("DB_PORT", 5432))

def get_db_connection():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASS,
            port=DB_PORT,
            connect_timeout=3
        )
        return conn, "postgres"
    except Exception as e:
        # Fallback to local SQLite if Postgres is unavailable
        conn = sqlite3.connect("/tmp/aeron_local.db")
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                category TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
        """)
        conn.commit()
        return conn, "sqlite"

def init_db():
    conn, db_type = get_db_connection()
    cursor = conn.cursor()
    if db_type == "postgres":
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS items (
                id SERIAL PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                category VARCHAR(100) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
    conn.close()

@app.route("/")
def index():
    init_db()
    conn, db_type = get_db_connection()
    cursor = conn.cursor()
    if db_type == "postgres":
        cursor.execute("SELECT id, name, category, created_at FROM items ORDER BY id DESC;")
    else:
        cursor.execute("SELECT id, name, category, created_at FROM items ORDER BY id DESC;")
    items = cursor.fetchall()
    conn.close()

    hostname = os.getenv("HOSTNAME", "unknown_container")
    environment = os.getenv("ENV_TYPE", "production")
    return render_template("index.html", items=items, hostname=hostname, environment=environment, db_type=db_type)

@app.route("/add", methods=["POST"])
def add_item():
    name = request.form.get("item_name")
    category = request.form.get("item_category")
    if name and category:
        conn, db_type = get_db_connection()
        cursor = conn.cursor()
        if db_type == "postgres":
            cursor.execute("INSERT INTO items (name, category) VALUES (%s, %s);", (name, category))
        else:
            now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            cursor.execute("INSERT INTO items (name, category, created_at) VALUES (?, ?, ?);", (name, category, now_str))
        conn.commit()
        conn.close()
    return redirect(url_for("index"))

@app.route("/delete/<int:item_id>", methods=["POST"])
def delete_item(item_id):
    conn, db_type = get_db_connection()
    cursor = conn.cursor()
    if db_type == "postgres":
        cursor.execute("DELETE FROM items WHERE id = %s;", (item_id,))
    else:
        cursor.execute("DELETE FROM items WHERE id = ?;", (item_id,))
    conn.commit()
    conn.close()
    return redirect(url_for("index"))

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
