# Local installation

## Requirements
1. Docker Desktop ([Installation](https://docs.docker.com/desktop/) - look for `Install Docker Desktop`).
2. Minikube for local Kubernetes orchestration (mainly for learning purpose) ([Installation](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fwindows%2Fx86-64%2Fstable%2Fchocolatey)).
3. Helm for kubernetes package management ([Installation](https://helm.sh/docs/intro/install/)).

## Running the application locally using Docker Compose
To spin up the application and database locally
```bash
docker compose -f ./web-app/docker-compose.yml --project-directory . up
```

Access the application at http://localhost/.

To safely shut down the environment
```bash
docker compose -f ./web-app/docker-compose.yml --project-directory . down
```

**Note:** The PostgreSQL database state will be preserved in a named volume for future runs. To completely destroy the application and wipe the database volume, append the -v flag to the down command.

**Security Note:** To keep this local learning environment simple, .env files have not been added to .gitignore. In a production environment, hardcoded secrets are strictly prohibited and would be managed securely via Kubernetes ConfigMaps/Secrets or an external secret manager like AWS Secrets Manager or HashiCorp Vault.

## Running the application on Kubernetes Minikube

Ensure Minikube is active by running `minikube status`.
If it is stopped, initialize it by running `minikube start`.

Deploy the application using the local Helm Chart:
```bash
helm install app ./helm-chart/visit-counter  # 'app' is a dynamic release name
```

To expose the web service from the Minikube cluster to your host machine:
```bash
minikube service visit-counter-dev-web-app-svc
```
This command will automatically open the application in your default web browser.

To shut down the application:
1. Terminate the active Minikube service process in your terminal (Ctrl+C).
2. Uninstall helm release by running `helm uninstall app`.

## Running monitoring namespace (Prometheus and Grafana)
Ensure Minikube is active by running `minikube status`.  
If it is stopped, initialize it by running `minikube start`.

Deploy Prometheus and Grafana using monitoring Helm Charts:
```bash
helm dependency build ./helm-chart/monitoring # downloads dependencies
helm install monitoring ./helm-chart/monitoring/ --namespace monitoring --create-namespace
```

To expose Grafana service from the Minikube cluster to your host machine:
```bash
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

Access Grafana UI at http://localhost:3000.

You will be asked to enter username and password
* Username: `admin`
* Password: run the following command and copy the password
  ```bash
  kubectl get secret --namespace monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
  ```

To remove the monitoring Helm Chart and dedicated namespace:
```bash
helm uninstall monitoring --namespace monitoring
kubectl delete ns monitoring
```

## Running Jenkins
To run Jenkins container, follow the instructions in [jenkins-installation-local.md](./MDs/jenkins/jenkins-installation-local.md).  
