FROM python:3.14.3-alpine3.23
RUN adduser -D -G root appuser
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN chmod -R 550 /app
USER appuser
EXPOSE 5000
HEALTHCHECK --timeout=3s \
    CMD wget --quiet --tries=1 --output-document=/dev/null http://127.0.0.1:5000/health || exit 1
CMD [ "python", "app.py" ]