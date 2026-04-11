# Phase 1

The purpose of Phase 1 is to establish a solid foundation by applying Docker concepts to create a basic environment for containerized applications.

We were requested to create a simple Python flask application, containerize it and use Docker volumes to manage persistent storage.

## Features
* Web app with 2 web pages: */* and */visits*.
* */visits* page shows a count of logging into the different pages of the app. Counts are stored in an SQLite DB file.
* SQLite DB is stored on a Docker bind mounts (on the host machine).
* Dockerized: Easily containerized for streamlined deployment.

## Project structure
```
src                     # Web app project
├───app.py              # Application entry point
├───docker-compose.yml
├───Dockerfile  
├───requirements.txt    # Python dependencies
├───db                  # SQLite DB related scripts
├───static
│   ├───css
│   └───images  
└───templates           # Jinja2 HTML templates (pages)
```
* Mentioned only relevant files

## Installation

### Requirements
1. Docker Desktop ([Installation](https://docs.docker.com/desktop/) - look for `Install Docker Desktop`).

### Running the application locally

```bash
cd src
docker compose up
```

Go to http://localhost/

Once finished, run the following to shut down the app
```bash
docker compose down
```
