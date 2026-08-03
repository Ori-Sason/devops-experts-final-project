# Learning notes

This section documents the architectural choices and technical insights I gained during development. These notes serve to clarify my decision-making process and provide a roadmap of the concepts I've mastered during this phase.

## Phase 1 - Docker

End phase commit: [7cbd55e](https://github.com/Ori-Sason/devops-experts-final-project/tree/7cbd55e752bfc8164f77ee508d1bf350186e32e0)

The purpose of Phase 1 is to establish a solid foundation by applying **Docker** concepts to create a basic environment for containerized applications.

We were requested to create a simple Python Flask application, containerize it and use Docker volumes to manage persistent storage.

### Notes
* DB - SQLite vs PostgreSQL / MySQL  
  We were asked to `Use Docker volumes to manage persistent storage if necessary`. To make things interesting, I've decided to make a page showing visit count which is stored on a DB.  
  At first I thought that a simple solution can be using SQLite. But thinking of the next phases, where we will use Kubernetes and deploy to AWS, SQLite won't suite (since different Pods located on different Nodes can't reach the same SQLite DB).  
  To understand both worlds, I've decided to use SQLite on this phase, and then move the DB to a different container in the next phase, where we will use Kubernetes (and consider using AWS RDS if we will deploy to AWS).  
  Two more key points:
  * In this phase I've used a Docker named volume. In the course we've learned about bind mounts, but since I've used `USER` instruction, it required to have the same user on both Docker and host machine. To avoid that, and as a simple solution, I preferred using named volume.
  * I wondered how PostgreSQL / MySQL will handle concurrency on Kubernetes. One idea I had is that I can have multiple DB Pods, where all of them reference to a single volume. After reading, seems like that I can have only a single DB StatefulSet and multiple Python Pods directing to it.  
  To scale up, having multiple DB instances requires more complex architecture, which can be reached by using AWS RDS.
* Dockerfile `USER`  
  While I've read and saw YouTube videos about this instruction, I've never used it. So, I though it will be a good chance to try it here.  
  Before applying to use it, I've read the following articles:
  * [Understanding the Dockerfile USER and Its Role in Docker Containers](https://cyberpanel.net/blog/docker-file-user-command) by Cyberpanel.
  * [Top 21 Dockerfile best practices for container security](https://www.sysdig.com/learn-cloud-native/dockerfile-best-practices) by sysdig.

  An easy way of implementing the `USER` instruction is described in a [Youtube video](https://youtu.be/8vXoMqWgbQQ?t=855&si=d6mW0IzEhfEMLdBe)
  ```Dockerfile
  RUN add group -r tom && useradd -g tom tom
  RUN chown -R tom:tom /app
  USER tom
  CMD node index.js
  ```
  Also, we can set the owner in the `COPY` command
  ```Dockerfile
  COPY --chown tom:tom . .
  ```
  However, according to the sysdig article above, point 1.4, we should avoid giving ownership to the non-root user. One of the reasons that it's not secure is because the owner of the files is able to change the permissions.  
  Therefore, I've used what seems to be OpenShift / Enterprise Linux approach. Here are some notes from Gemini:
  * **Group 0 (root) Strategy**: Adding your user to the `root` group (`-G root`) and setting `chgrp -R 0` is the gold standard for OpenShift. It ensures that even if a platform runs your container with a random, high-numbered UID (a common security feature), that random user will still belong to GID 0 and have the permissions you defined.
  * **The X (Uppercase) Bit**: Using `g+rwX` is a smart touch. In Linux, the uppercase X means "apply execute permissions only if it's a directory or already has execute bits." This allows your user to enter the folder without accidentally making every data file inside an executable script.
  * **Immutable Code**: Keeping `/app` at `550` while the DB is `g+rwX` perfectly maintains that "read-only code, writeable data" balance.  

  Therefore I've used the following approach:
    ```Dockerfile
    # Create a user without a password and add it to the root group
    # (Note: GID 0 is a system group and does not grant admin/root user privileges).
    RUN adduser -D -G root appuser

    ... # Install and copy files instructions

    # 1. Secure the app directory: Read & Execute for user/group, completely blocked for others (550).
    # 2. Explicitly set group ownership of the DB folder to GID 0 as a fail-safe for future code changes.
    # 3. Grant Write permissions to the root group on the DB folder so SQLite can manage its journal files.
    RUN chmod -R 550 /app && \
    chgrp -R 0 /app/db/dbs && \
    chmod -R g+rwX /app/db/dbs
    ```
* `.dockerignore` vs `.gitignore` references  
  In `.dockerignore`, a pattern like `__pycache__` only matches in the root folder. To match it recursively (like `.gitignore` does by default), we should use `**/__pycache__`.
* `pip install --no-cache-dir` flag  
  Docker stores a copy of the `.whl` or source files in the layer, nearly doubling the space required for your dependencies. Using `--no-cache-dir` keeps your production image slim.  
  Also, it helps with a security concern. From [Datadog Docs](https://docs.datadoghq.com/security/code_security/static_analysis/static_analysis_rules/docker-best-practices/pip-no-cache/): It is important to avoid using a cache when installing packages because it ensures that the latest version of a package is always used. This reduces the risk of security vulnerabilities and bugs, and ensures that your application has the most up-to-date and secure dependencies.
* Moving files using git  
`git mv source_folder/* destination_folder/`  
  I had to move files from one folder to another, which caused them to change status to `untracked`. This results the commit looks like I've deleted the old files and created new ones instead.  
  By using Git `mv` command, the status of the files changes to `rename`, which better describes the situation.
* `HEALTHCHECK`  
  In the next stage we will be required to use Kubernetes Readiness and Liveness Probes. Docker also suggest a liveness test, which just indicates whether the app running on the container is healthy. Unlike Kubernetes, it doesn't restart the container, but just mentions the health status on `docker ps` output.  
  I've read the [official documentation](https://docs.docker.com/reference/dockerfile/#healthcheck) about this instruction.  
  Since `curl` is not installed on Alpine images, and I didn't want to add an extra layer, I've used `wget` command.

## Phase 2 - Kubernetes

End phase commit: [e8e6eb3](https://github.com/Ori-Sason/devops-experts-final-project/tree/e8e6eb3387c5cb9c6047a151762f8879489a6b5c)
* I've updated the image name of my web-app container from `orisason1/devops-experts-s4e3` to `orisason1/devops-experts-final-project`. In case you're cloning any of this phase commits, update the image name in `./kubernetes/web-deployment.yml`.

The objective of Phase 2 is to build upon our containerization knowledge by orchestrating our application with **Kubernetes** to ensure it is scalable and highly available.

We were requested to set up a cluster using Minikube to deploy your application, manage it using Deployments and Services, and implement advanced features like Horizontal Pod Autoscaling, ConfigMaps, Secrets and CronJobs.

### Notes
* I've removed part of the permissions command mentioned on Phase 1 since I don't use SQLite anymore (as planned on Phase 1, I've created a separated container running PostgreSQL).
* Pod dependency order  
  My web app depends on the DB, but Kubernetes starts all Pods simultaneously. Unlike Docker Compose’s `depends_on`, Kubernetes requires an init container in the web-app Pod to "gate" the startup. It polls the DB Service (DNS/Port) and only exits once the DB is ready, allowing the main app container to finally start.

## Phase 3 - Helm Charts, Git and Jenkins

End phase commit: [096fb63](https://github.com/Ori-Sason/devops-experts-final-project/tree/096fb6330e43f984a92a163ede7c6ebdfb5316cf)

The objective of Phase 3 focuses on automating the deployment process and improving version control practices.  

We are requested to create a **Helm Chart** for our Kubernetes application, set up a **Git** repository to manage our project workflows, and use **Jenkins** to implement a local CI/CD pipeline with build, test, and deploy stages.

### Notes
* Git Hooks  
  Since we're asked to use Git at this phase, I thought it can be a good chance to try using pre-commits hooks. I've heard about this feature, but never used or configured it on my own.  
  I use [pre-commit](https://pre-commit.com/) framework for managing and maintaining pre-commit hooks. From that framework I use two built-in hooks: `end-of-file-fixer` to check that files end with empty line and `trailing-whitespace` which makes sure that there are no trailing whitespaces.  
  In the next phase we will use AWS, so I use [Gitleaks](https://github.com/gitleaks/gitleaks) to detect secrets before committing them.

  I want to use pre-commit hooks only locally. There is no need to install it as part of CI/CD pipeline or on deployed environment. Therefore, I will use Python uv package and project manager that will allow me to manage installations for dev-environment only easily.
* Using python uv instead of pip  
  This is also the first time I'm using uv (in my last startup we were using `pip`, virtual environment by `python -m venv` and `requirements.txt` files).  
  I've learned the fundamentals of uv from a YouTube video: [Stop Using Pip - This New Tool is 100x Faster (uv Tutorial)](https://www.youtube.com/watch?v=6pttmsBSi8M) by Tech With Tim.

  Few decisions and learning extras related to uv:  
  * Up to this point, in Dockerfile I used `pip` and `requirements.txt` file. I had to decide whether to keep it or use uv when building the image.  
    Staying with `pip` is the easy choice since `pip` approach is already implemented on Dockerfile.  
    However, then I will have different package managing systems in the same small project. Also, uv is much faster installing, which can be beneficial in case of rebuilding the Docker image.  
  * Another feature uv offers is creating `requirements.txt` file out of `uv.lock`, by running the following command:
    ```bash
    uv export --format requirements-txt --output-file requirements.txt
    ```
    Therefore, I could generate that text file automatically by using Git pre-commit/pre-push hooks or as part of the CI/CD pipeline. But that felt cumbersome.

    ***I've decided to use uv on Dockerfile.***

  * In my project, I have two layers of uv usage - on the root level I use `pre-commit` manager, while on `web-app/` I use the packages that were in `web-app/requirements.txt` (like Flask and psycopg2).  

    Using Gemini I've become familiar with a feature uv offers, called workspace. Using this feature I can have 2 TOML files (uv configuration file. Like `package.json` in NodeJS NPM projects) - one in the root folder and one in `web-app/`.  
    ```
    . (root)
    ├── pyproject.toml
    ├── uv.lock
    └── web-app/
        └── pyproject.toml
    ```

    In the root folder TOML file we have a reference to the file on `web-app` folder.
    ```toml
    [tool.uv.workspace]
    members = ["web-app"]
    ```

    When we run uv locally, there is only a single virtual environment folder, `.venv/`, which is located on the root folder.  
    uv scopes the package execution context to the directory we execute `uv run`. In other words, when we run
    ```bash
    cd web-app
    uv run app.py
    ```
    uv scopes only the dependencies in `web-app/pyproject.toml`.
  * To make sure that the exact same dependencies installed locally will be installed on the Docker image, we need to copy `uv.lock` file to the Docker image.  
    Therefore, we need to build the Docker image in the context of the root folder. Technically it means that we need to to run the build command from the root folder, so Docker will have access to `./uv.lock`.
  * I've updated Dockerfile and used a build stage. On the build stage I've installed uv, copied `./web-app/pyproject.toml` and `./uv.lock` files to ensure strict version pinning, and compiled the virtual environment on `/app/.venv/` folder.  
    In the final stage I've copied the content of `/app/.venv/` from the build stage, and updated the `PATH` environment variable to reference to the virtual environment folder.  
    As a result, I'm using uv **only** in the build stage, so the final image is kept lean.
  * Explanations about the build step  
    Instead of installing uv, I copy uv binaries into the image
    ([uv Docks](https://docs.astral.sh/uv/guides/integration/docker/#installing-uv))
    ```Dockerfile
    COPY --from=ghcr.io/astral-sh/uv:0.11.18 /uv /uvx /bin/
    WORKDIR /app
    COPY ./uv.lock .
    ```
    Since `uv.lock` content fits to a scenario of workspace with members, I have to replicate the files and folders structure in the image.  
    Instead of copying the root folder `pyproject.toml` file, I create one during the build process, containing only a reference to the `web-app` folder.
    ```Dockerfile
    RUN echo -e '[tool.uv.workspace]\nmembers = ["web-app"]' > pyproject.toml
    COPY ./web-app/pyproject.toml ./web-app/
    RUN uv sync --frozen --no-dev --no-install-workspace --package web-app
    ```
    For more information about `uv sync` flags - [uv Docs](https://docs.astral.sh/uv/reference/cli/#uv-sync)
    * `--frozen`: forbids updating `uv.lock` file. Ensuring the same dependencies versions as in dev environment.
    * `--no-dev`: excludes dev-only dependencies.
    * `--no-install-workspace`: installs only package dependencies (without root dependencies).
    * `--package`: syncs for specific packages in the workspace.
  * Since Dockerfile content is written now in the context of the root folder, it also influences `docker build` and Docker Compose commands
    ```bash
    docker build -f ./web-app/Dockerfile -t <image-tag> .
    docker compose -f ./web-app/docker-compose.yaml --project-directory . up
    docker compose -f ./web-app/docker-compose.yaml --project-directory . down [-v]
    ```
  * Explanation about build context  
    Since we build from the root folder, this is the context Docker sees. Therefore, I had to update 3 things:
    * Updated `Dockerfile` and `docker-compose.yaml` content so it will be in the context of the root folder.
    * Moved `.dockerignore` from `web-app` folder to the root folder.  
    I could keep it in `web-app` folder and refer to it in the build command by using the `--dockerignore` flag. But then I had to update the content inside the file. Since I can have many Dockerfiles in a project (even though I have only one here), I've decided to have a main standard `.dockerignore` file for the whole project in the root directory.
* Python `PATH` environment variable  
  In Dockerfile I've chained the `PATH` variable
  ```Dockerfile
  ENV PATH="/app/.venv/bin:$PATH"
  ```
  The `PATH` variable isn't just a single folder, it is a colon-separated list of directories that the operating system searches from left to right whenever we run a command.  
  A standard Linux container comes out of the box with a `PATH` that looks something like this: `/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin`.  
  Now, when the container runs health check by using `wget`, it will first look for that package at `/app/.venv/bin`. Since it won't find it there, it will try the following folders, started from `/usr/local/bin` and on.
* Helm `_helpers.tpl` functionality  
   This file is used to abstract complex string logic into reusable templates. I implemented a dynamic function named `componentName` that accepts a `list` containing the root context (`.`) and a component string identifier. It returns a uniform naming convention: `<chart name>-<stage>-<component name>`, while utilizing `trunc 63` to guarantee compliance with Kubernetes DNS limits.  
* Kubernetes standard labels  
  I used the official community standard prefix `app.kubernetes.io/` for resource labeling. This ensures universal compatibility with DevOps observability tools (like Prometheus), prevents name collisions with cloud providers, and clearly distinguishes internal system metadata from business logic.
* Publishing the Helm Chart  
  While publishing to an OCI-compliant registry (such as GitHub Packages) is the modern industry standard for distributing Helm charts, I explicitly chose to host the chart using **GitHub Pages** due to security constraints regarding credential scoping.  
  * The OCI vs. GitHub Pages Dilemma  
    OCI (Open Container Initiative) is a standard designed for container images that has evolved to support alternative cloud-native artifacts like Helm Charts. However, authenticating with GitHub Packages (GHCR) via external automation (like Jenkins) requires a Classic Personal Access Token (PAT). GitHub strictly forces the Classic PAT's `write:packages` scope to inherit full read/write access to **all** repositories across the entire account, violating the principle of least privilege.  
  * The Secure Alternative:  
    To mitigate this security risk, I utilized GitHub Pages paired with a Fine-Grained PAT. This allowed me to restrict Jenkins' write permissions exclusively to this single, specific repository.  
  * Deployment Mechanics  
    Jenkins pipeline packages the chart, updates the tracking index, and pushes the artifacts to the `helm-publish` branch, which is configured to serve GitHub Pages.  
  * To add the repository and install the chart:
    ```bash
    helm repo add myrepo https://ori-sason.github.io/devops-experts-final-project/ # myrepo is a dynamic name
    helm install my-release myrepo/visit-count
    ```  
    Note: Replace `install my-release` with `pull` to download the chart compressed file, without deploying it to the cluster.
* Notes related to Jenkins can be found in [jenkins-notes.md](./MDs/jenkins-notes.md) and [running-jenkins.md](./running-jenkins.md).
* Helm test
  * `wget -T 5 -t 3 <URL>` - try 3 times with a 5-second timeout before giving up.
  * I've set the `web-app` service type to `ClusterIP` instead of `LoadBalancer` in `values-test.yaml`.  
    The reason for this is that when a `LoadBalancer` service is created in Minikube, its `EXTERNAL-IP` status remains stuck as `<pending>` by default. In the [Jenkinsfile](/jenkins/Jenkinsfile) `helm-chart: test` stage, I install the Helm chart on the cluster before running the connection tests. Since it takes time for the database and application pods to spin up, I use the `--wait` flag in the `helm install` command. One of the requirements for Helm to consider a `LoadBalancer` service 'ready' (and thus stop waiting) is for its `EXTERNAL-IP` to be provisioned with a real IP or hostname. Because Minikube lacks a cloud controller to assign external IPs natively, Helm never receives this status update inside the isolated Jenkins container network environment (`EXTERNAL-IP` stays `<pending>`). As a result, the pipeline blocks on the `helm install` command until it hits the timeout.  
    Switching the service type to `ClusterIP` for the test environment seamlessly resolves this, as Helm no longer expects an external IP address.  
    If I were deploying this to a live cloud infrastructure provider (like AWS or GCP), an external load balancer IP would be provisioned automatically, and the command would succeed without getting stuck.

## Phase 4 - Monitoring, AWS and Ansible

#### FIX - add description of the phase

### Notes
* Monitoring (Prometheus and Grafana)
  * When we want to use public charts in our own chart, we should define the dependencies charts in `Chart.yaml` file, under `dependencies` property.  
    To update the charts versions in this case:
    * Update the version under `dependencies` property in `Chart.yaml` file.
    * Run `helm dependency update <chart-location>`.
  * Once you install the chart, dependencies will be creates under `charts/` folder. These are compressed `.tgz` files.  
    We avoid uploading `*.tgz` files to GitHub because these binary archives unnecessarily inflate the repository size. Instead, we rely on the details in the `Chart.lock` file. Therefore, I've added this folder content to `.gitignore`.  
    When a user download the repository, it won't have the compressed files in `./helm-chart/monitoring/charts`.
    Therefore, he should run `helm dependency build <chart-location>`, which downloads the dependencies as compressed charts, based on `Chart.lock` file. Only then we can run `helm install <chart-location>`.
  * In order to have a dashboard in Grafana, we should add Prometheus as a datasource and import a Dashboard.  
    Instead of doing it manually in the UI, I wanted to add an automation. The connection is configured in [values.yaml](/helm-chart/monitoring/values.yaml) and in 2 ConfigMaps inside `templates/` folder.
    * Creating the datasource automatically is done by enabling `datasources` in `values.yaml` file, and ConfigMap [grafana-datasource-configmap.yaml](/helm-chart/monitoring/templates/grafana-datasource-configmap.yaml).  
      The embedded `datasource.yaml` file (in the datasource ConfigMap) configures the connection details within Grafana:
      * `name: Prometheus` display name that appears in Grafana dashboard dropdown menus.
      * `type: prometheus` tells Grafana to use its built-in Prometheus query plugin.
      * `url` is the internal Kubernetes DNS address (`http://cluster.local`) used by Grafana to pull data from the Prometheus service.
      * `access: proxy` directs Grafana to route queries through its own server backend rather than from the user's browser.
      * `isDefault: true` immediately query this data source without needing manual adjustments in the UI.
    * Creating the dashboard automatically is done by enabling `dashboards` in `values.yaml` file, and ConfigMap [grafana-dashboard-configmap.yaml](/helm-chart/monitoring/templates/grafana-dashboard-configmap.yaml).  
      I import a dashboard JSON file to the ConfigMap instead of installing it from the internet. Few reasons for that:
      1. By that, I make sure that we use exactly the same dashboard over time (in case a revision is updated).
      2. I had some errors downloading a dashboard automatically, and I've found that using a manual dashboard is more reliable.
      3. I've noticed that some of the panels weren't working on the published dashboard and I had to manipulate the file (more on that on `update-dashboard-json` script explanation).
    * labels `grafana_datasource: '1'` and `grafana_dashboard: '1'`  
      Grafana installations (like those deployed via Helm charts) run a sidecar container. This sidecar continuously scans the cluster for ConfigMaps with this specific label and automatically injects them into Grafana without requiring a manual restart.  
      Instead of letting Grafana scan every single ConfigMap in the Kubernetes cluster, we tell the sidecar to only intercept ConfigMaps labeled as defined in the `sidecar` configuration.
    * `update-dashboard-json` Python script
      Some of the panels didn't work and I had to manipulate the code a bit. I've created a Python script in case a new revision will be published and I'll need to update the JSON file.
      You can find the replacements at the top of the file:
      * Removed `{cluster="$cluster"}`  
        A local Prometheus instance does not inject a `cluster` identity label into its local Time Series Database (TSDB - the DB of Prometheus). `cluster` labels are only appended as `external_labels` when forwarding data out of the environment (e.g., via `remote_write` to a global aggregator, like when forwarding alerts to an Alertmanager or shipping metrics to a centralized Prometheus server). Since Grafana is querying the local TSDB directly, the label does not exist, causing queries with this filter to return `No Data`.  
        The following 2 fixes, related to `job` and `mode="idle"`, are just to keep the PromQL syntax clean.
      * Removed `{image!=""}`  
        Since `kubelet` version `1.24`, Docker plugin from `cAdvisor` was removed. Therefore, `cAdvisor` could not fetch Docker container infos about image labels and so on ([GitHub issue 111077](https://github.com/kubernetes/kubernetes/issues/111077#issuecomment-1183914189)).  
        * `cAdvisor` (Container Advisor) is an open-source agent built directly into Kubernetes (embedded in the `kubelet` process) that automatically discovers, collects, and processes resource usage statistics for running containers.  

        Therefore, there are no metrics using `image` label, so having that label on the query doesn't return results. As a result, the panel will have a `No Data` message at the center of it.  
        To solve that I've simply removed this label from the query.
      * Updated `Container Restarts by namespace` and `OOM Events by namespace` panels. Both of these showed `No Data` label when the number of events was `0`. I've preferred to show `0` value instead of that. Also, preferred showing the exact number of events at a certain timeframe (`$__range`) rather the original manipulated calculation (`$__rate_interval`).  
    * Grafana `side car`  
      The Grafana Sidecar is a helper container running alongside Grafana inside its pod. Its sole job is to automatically detect and load configurations dynamically from our cluster so we don't have to restart Grafana or hardcode configurations in our main configuration files.
* AWS Architecture
  * The AWS architecture diagram is available in the [README.md](/README.md#aws-architecture) file.  
    First, it is worth mentioning that **this design is an overkill** for a project at this scale. However, my goal was to simulate a production-ready environment featuring a K3s Kubernetes cluster running across multiple nodes, a dedicated instance for Jenkins, and an Amazon RDS database instead of a Docker container running inside the cluster.
  * K3s Cluster
    * I chose K3s over Minikube to enable running the cluster across multiple EC2 instances. Only the `web-app` nodes are exposed to the Application Load Balancer (ALB), while the Monitoring and Control Plane nodes remain isolated from the internet.
    * Because K3s does not natively scale nodes automatically, node scaling is managed via an AWS Auto Scaling Group (ASG). While managed alternatives like AWS EKS or kOps handle node scaling out of the box, I opted for this self-managed K3s approach to keep costs minimal.
  * The ALB listener serves HTTP only, not HTTPS — adding TLS would require a domain name and an ACM certificate, which I intentionally left out of scope here.
  * Instances security, IMDSv2 and hop limit  
    IMDSv2 requires a session token to fetch instance credentials from `169.254.169.254`, protecting against SSRF-based credential theft. This address is a link-local address AWS reserves for the Instance Metadata Service (IMDS) — among other things, it's where an instance retrieves the temporary credentials for its attached IAM role. That token request has a hop limit (`http_put_response_hop_limit`) — by default we allow only `1` hop. But since ESO's pod (described below) needs to reach IMDS from its own network namespace, we allow `2` hops on the master node (pod → host network namespace, host → IMDS).
  * Jenkins Security
    * Jenkins runs within an isolated private subnet due to its high privilege levels. I configured Security Groups to block all communication from the K3s nodes to the Jenkins instance. To add an extra layer of defense-in-depth, Network Access Control Lists (NACLs) could also be implemented to completely block traffic between the K3s private subnet and the Jenkins private subnet.
  * Session Manager
    * While I was already familiar with using a bastion host (or "jump server") to connect to instances in private subnets, I wanted to explore modern alternatives. I came across the article, [*Secure Access to Private EC2 Instance in Private Subnet Methods and Best Practices*](https://medium.com/@hobballah.yasser/secure-access-to-private-ec2-instance-in-private-subnet-methods-and-best-practices-d4ee75a506d3) by Yasser Hobballah, which outlines four approaches: Bastion Host, Session Manager via NAT Gateway, Session Manager via VPC Endpoints, and EC2 Instance Connect Endpoint.
    * Since this architecture already utilizes a NAT Gateway to install packages on the EC2 instances and allow Jenkins to push images to Docker Hub, I opted for the second approach: AWS Systems Manager Session Manager (Note: while I could have built a custom AMI with the required software pre-installed, I wanted the entire cluster to provision dynamically from scratch using a single `terraform apply` command).
    * Session Manager is a fully managed AWS Systems Manager tool. It allows secure management of EC2 instances without exposing them to the internet or opening inbound ports. Behind the scenes, the AWS SSM Agent installed on the instance relies on a outbound polling mechanism - checking in with the AWS Systems Manager API for pending connection requests - which is why it works perfectly via a NAT Gateway without requiring an Internet Gateway (IGW) route.  
    With this setup, I can log directly into an instance:
      ```bash
      aws ssm start-session --target <instance-id>
      ```
      Or establish a port-forwarding session to access an application UI from a local browser:
      ```bash
      aws ssm start-session \
        --target <instance-id> \
        --document-name AWS-StartPortForwardingSession \
        --parameters '{"portNumber":["<instance-port>"],"localPortNumber":["<local-port>"]}'
      ```
  * RDS
    * In production I chose running PostgreSQL DB on AWS RDS, instead of running DB on a pod, to simulate production environment. AWS requires an RDS DB Subnet Group to cover at least 2 Availability Zones (AZ) for failover readiness. Because the main infrastructure resides in a single AZ, I added a secondary empty subnet (`rds_priv_2`) in a second AZ purely to fulfill this AWS requirement without additional cost.

    * Unlike local environment, I wanted to hide my DB secrets while uploading to GitHub.  
      When we run `terraform apply`, Terraform adds the secrets in `secrets.auto.tfvars` to the clusters `vars` automatically. In our case, we add `db_username` and `db_password`, as mentioned in [secrets-auto-tfvars.example](/terraform/secrets-auto-tfvars.example) (we have to rename the file and fill in the credentials before running `terraform apply`).  

      Next, we want to upload those secrets to AWS SSM parameter store along with the database name and RDS address, so the Kubernetes cluster will be able to fetch these parameters. We do that in [rds.tf#aws_ssm_parameter.db_credentials](/terraform/rds/rds.tf).  

      Lastly, we need to fetch these parameters in the Kubernetes cluster. To do that I've used an external secret operator by [external-secrets.io](https://external-secrets.io). This component allows adding secrets to Kubernetes cluster from cloud providers or secret management platforms.  

      So, we install the resources on a namespace named `external-secrets`. On the installation command we pin the controller pod to the master node, by `--set-string nodeSelector."node-role\.kubernetes\.io/control-plane"=true`. We pin the controller pod to the master node, since we set that only the K3s master node's IAM role has permission to read that SSM parameter (see [rds/iam.tf](/terraform/rds/iam.tf)).

      Then we add 2 more components to our Kubernetes cluster: [ClusterSecretStore](/helm-chart/visit-counter/templates/db-rds/cluster-secret-store.yaml) creates the connection to AWS and [ExternalSecret](/helm-chart/visit-counter/templates/db-rds/external-secret.yaml) fetches the secrets from SSM parameter store.  

      Once we install the Helm Chart, `ExternalSecret` will create a `Secret` component with the parameters we stored on [rds.tf#aws_ssm_parameter.db_credentials](/terraform/rds/rds.tf): `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` and `DB_HOST`.
    * In Helm Chart, I kept the option to use a Pod running DB inside, instead of AWS RDS.  

      For that, keep the DB enabled in [values-prod.yaml](/helm-chart/visit-counter/values-prod.yaml) and comment out the RDS instance in Terraform code.  

      Worth mentioning that this scenario is supported when we have a single node running the Web App pods. In case there is more than one node, we need to add port `5432` (Postgres port) to Web App Security Group.
* AWS
  * To view EC2 provisioning script output:
    * log he instance using SSH
      ```bash
      ssh -i <path to .pem file> ec2-user@<EC2 instance public IP>
      ```
      Or AWS SSM session
      ```bash
      aws ssm start-session --target <EC2 instance ID>
      ```
    * In the instance terminal, run
      ```bash
      sudo cat /var/log/cloud-init-output.log
      ```
  * To read provisioning script `user_data.txt` (necessary when it was manipulated with by Terraform and you want to debug):
    * Log the EC2 instance with SSH or AWS SSM session, as described above.
    * In the instance terminal, run
      ```bash
      sudo cat /var/lib/cloud/instance/user-data.txt
      ```
