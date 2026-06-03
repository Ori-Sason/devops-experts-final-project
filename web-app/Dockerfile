FROM python:3.14.3-alpine3.23 AS build
COPY --from=ghcr.io/astral-sh/uv:0.11.18 /uv /uvx /bin/
WORKDIR /app
COPY ./uv.lock .
RUN echo -e '[tool.uv.workspace]\nmembers = ["web-app"]' > pyproject.toml
COPY ./web-app/pyproject.toml ./web-app/
RUN uv sync --frozen --no-dev --no-install-workspace --package web-app

FROM python:3.14.3-alpine3.23
RUN adduser -D -G root appuser
WORKDIR /app
COPY --from=build /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"
COPY ./web-app/ .
RUN chmod -R 550 /app
USER appuser
EXPOSE 5000
HEALTHCHECK --timeout=3s \
    CMD wget --quiet --tries=1 --output-document=/dev/null http://127.0.0.1:5000/health || exit 1
CMD [ "python", "-m", "src.app" ]
