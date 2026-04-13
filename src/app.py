import os
from functools import wraps
import hashlib
from flask import Flask, render_template, request, redirect, url_for, jsonify
from db.visit_count import increment_visit, get_visits


app = Flask(__name__)


def count_visits(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        increment_visit(request.path)
        return func(*args, **kwargs)
    return wrapper


@app.route('/')
@count_visits
def main():
    return render_template('index.html')


@app.route('/visits')
@count_visits
def visits():
    return render_template('visits.html', visits=get_visits())


@app.route('/health')
def health_check():
    return {"status": "healthy"}, 200


@app.route('/stress')
def stress_cpu():
    # This creates actual CPU heat by calculating 5,000 hashes per request
    for _ in range(5000):
        hashlib.sha256(os.urandom(1024)).hexdigest()
    return jsonify(status="CPU Stressed")


@app.errorhandler(404)
def page_not_found(e):
    request.path = '/'
    return redirect(url_for('main'))


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=os.environ.get('WEB_APP_PORT', 5000))
