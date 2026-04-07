from functools import wraps
from flask import Flask, render_template, request
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


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True) # FIX - remove debug
