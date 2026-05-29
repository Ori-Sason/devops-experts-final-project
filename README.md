# DevOps Experts - Final Project
<u>Author</u>: Ori Sason  
This is the final project for the DevOps Experts program. I update it regularly during the course to include the new technologies and layers we study in each phase.

I've noted my technical decisions and learning process in [learning-notes.md](./MDs/learning-notes.md).

## Features
* Web app with 2 web pages: */* and */visits*.
* */visits* page shows a count of logging into the different pages of the app.
* For DB, I use PostgreSQL container, which stores on a Docker named volume (on local deployment) or on Kubernetes hostPath (on K8s deployment).
* Dockerized: easily containerized for streamlined deployment.
* Kubernetes cluster deployed locally on Minikube (using Helm Charts).
* Support HPA - Horizontal Pod Autoscaling (check out [HPA.md](./MDs/HPA.md))
* Traffic cronjob - creates synthetic traffic to the application (check out [traffic-cronjob.md](./MDs/traffic-cronjob.md))

# Web App
<div align="center">
  <img src="./MDs/images/web-app.png" alt="Web app UI" width="600"/>
</div>

## Project structure
```
helm-chart
MDs                     # Notes
web-app                 # Web app project
├───app.py              # Application entry point
├───docker-compose.yml
├───Dockerfile  
├───requirements.txt    # Python dependencies
├───db                  # DB related scripts
├───env
├───static
│   ├───css
│   └───images  
└───templates           # Jinja2 HTML templates (pages)
```
* Mentioned only relevant files

## Kubernetes architecture
<div align="center">
  <img src="./MDs/images/kubernetes-architecture.png" alt="Architecture design" width="450"/>
</div>

## Installation

### Requirements
1. Docker Desktop ([Installation](https://docs.docker.com/desktop/) - look for `Install Docker Desktop`).
2. Minikube (local Kubernetes for learning purposes) ([Installation](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fwindows%2Fx86-64%2Fstable%2Fchocolatey)).
3. Helm Charts ([Installation](https://helm.sh/docs/intro/install/))

### Running the application locally using Docker Compose

```bash
docker compose -f ./web-app/docker-compose.yml --project-directory . up
```

Go to http://localhost/

Once finished, run the following to shut down the app
```bash
docker compose -f ./web-app/docker-compose.yml --project-directory . down
```

The DB will be stored for next runs on a named volume.
In case you want to completely remove the application, including the DB volume (DB data will be lost), add `-v` flag in the end of the command.

* To keep things simple, I didn't add `.env` files to `.gitignore` (or ConfigMap / Secret on K8s).
  On a real project, `.env` files shouldn't be uploaded to GitHub.

### Running the application on Kubernetes Minikube

Make sure Minikube is up an running by running `minikube status`.
If it's not, run `minikube start`.

To run the application
```bash
helm install app ./helm-chart/  # app is the release name, which is dynamic
```

Next, we need Minikube to expose the web service to our host machine
```bash
minikube service visit-counter-dev-web-app-svc
```

This will open a tab on your browser showing the web app.

To shut down the application:
1. Stop the process of `minikube service visit-counter-dev-web-app-svc`.
2. `helm uninstall app`
