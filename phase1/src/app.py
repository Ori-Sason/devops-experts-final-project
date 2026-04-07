from functools import wraps
from flask import Flask, render_template, request
from db.visit_count import increment_visit


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
def visits():
    # FIX - get visits from DB
    return render_template('visits.html', visits=[{'path': '/', 'count': 2}, {'path': '/visits', 'count': 3}])


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True) # FIX - remove debug