import hashlib
import os
from functools import wraps

from flask import Flask, jsonify, redirect, render_template, request, url_for

from src.db.visit_count import get_visits, increment_visit

app = Flask(__name__)


def count_visits(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        increment_visit(request.path)
        return func(*args, **kwargs)

    return wrapper


@app.route("/")
@count_visits
def main():
    return render_template("index.html")


@app.route("/visits")
@count_visits
def visits():
    return render_template("visits.html", visits=get_visits())


@app.route("/health")
def health_check():
    return {"status": "healthy"}, 200


@app.route("/stress")
def stress_cpu():
    # This creates actual CPU heat by calculating 5,000 hashes per request
    for _ in range(5000):
        hashlib.sha256(os.urandom(1024)).hexdigest()
    return jsonify(status="CPU Stressed")


@app.errorhandler(404)
def page_not_found(e):
    request.path = "/"
    return redirect(url_for("main"))


if __name__ == "__main__":
    # nosec B104 is making bandit ignore. It complains about 0.0.0.0, while it's required for Docker container networking
    app.run(host="0.0.0.0", port=os.environ.get("WEB_APP_PORT", "5000"))  # nosec B104
