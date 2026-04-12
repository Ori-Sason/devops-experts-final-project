# DevOps Experts - Final Project
<u>Author</u>: Ori Sason  
This is the final project for the DevOps Experts program. We update it regularly during the course to include the new technologies and layers we study in each phase.

## Features
* Web app with 2 web pages: */* and */visits*.
* */visits* page shows a count of logging into the different pages of the app. Counts are stored in an SQLite DB file.
* SQLite DB is stored on a Docker named volume.
* Dockerized: easily containerized for streamlined deployment.

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

The DB will be stored for next runs.
Run `docker compose down -v` if you want to completely remove the application, including the DB.
