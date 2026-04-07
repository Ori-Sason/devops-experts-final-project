FROM python:3.14.3-alpine3.23
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 5000
CMD [ "python", "app.py" ]