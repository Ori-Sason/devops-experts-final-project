This section documents the architectural choices and technical insights I gained during development. These notes serve to clarify my decision-making process and provide a roadmap of the concepts I've mastered during this phase.

## Phase 1 - Docker

End phase commit: [7cbd55e](https://github.com/Ori-Sason/devops-experts-final-project/tree/7cbd55e752bfc8164f77ee508d1bf350186e32e0)

The purpose of Phase 1 is to establish a solid foundation by applying **Docker** concepts to create a basic environment for containerized applications.

We were requested to create a simple Python flask application, containerize it and use Docker volumes to manage persistent storage.

### Notes
* DB - SQLite vs PostgreSQL / MySQL  
  We were asked to `Use Docker volumes to manage persistent storage if necessary`. To make things interesting, I've decided to make a page showing visit count which is stored on a DB.  
  At first I thought that a simple solution can be using SQLite. But thinking of the next phases, where we will use Kubernetes and deploy to AWS, SQLite won't suite (since multiple Pods, in multiple Nodes can't reach it).  
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

The objective of Phase 2 is to build upon our containerization knowledge by orchestrating our application with **Kubernetes** to ensure it is scalable and highly available.

We were requested to set up a cluster using Minikube to deploy your application, manage it using Deployments and Services, and implement advanced features like Horizontal Pod Autoscaling, ConfigMaps, Secrets and CronJobs.

### Notes
* Pod dependency order  
  My web app depends on the DB, but Kubernetes starts all pods simultaneously. Unlike Docker Compose’s `depends_on`, Kubernetes requires an init container in the web-app Pod to "gate" the startup. It polls the DB Service (DNS/Port) and only exits once the DB is ready, allowing the main app container to finally start.
