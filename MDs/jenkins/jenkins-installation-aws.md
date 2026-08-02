# Jenkins Installation

After installing the cluster by following [aws-installation.md](../aws-installation.md) guide, you can log Jenkins UI by running
```bash
aws ssm start-session --target $(aws ec2 describe-instances --filters "Name=tag:Name,Values=devops-experts-jenkins" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text) --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}'
```

And then browse to http://localhost:8080.

* Explanation for running command on [Jenkins EC2 provisioning script](/terraform/jenkins/scripts/ec2_provision.sh) can be found on [running-jenkins.md](./running-jenkins.md).

If this is your first time deploying Jenkins for this project, you must configure the required authentication credentials and create the pipeline job. Follow this step-by-step setup guide:

* Generate **GitHub** Personal Access Token (PAT)
  * Fork my repository
  * Create GitHub PAT
    * Profile menu → `Settings` → `Developer Settings` (sidebar menu) → `Fine-grained tokens` (sidebar menu) → `Generate new token`
      * Token name: `jenkins`
      * Expiration: `7 days` (or your preferred duration)
      * Repository access: Select `Only select repositories` and choose your forked repository.
      * Permissions:
        * `Contents` - read and write (for pushing to `helm-publish` branch)
        * `Metadata` - read-only (automatically added by selecting `Contents`)
        * `Pull requests` - read-only (required for the multibranch PR pipeline)
        * `Commit statuses` - read and write (requires for Pipeline GitHub Notify Step plugin)

      Click on `Generate token` and copy the secret.
* Store PAT on Jenkins
  * `Manage Jenkins` → `Credentials` → `Add Credentials` → `Username with password`
    * Username: `<your GitHub username, as it appears in GitHub URL>`
    * Password: `<paste PAT here>`
    * ID: github
    * Description: GitHub

    Click on *Create*
* Create **Docker Hub** PAT
  * Personal menu → `Account settings` → `Settings` (sidebar menu) → `Personal access tokens` (sidebar menu) → `Generate new token`
    * Access token description: `jenkins`
    * Expiration date: `30 days` (or your preferred duration)
    * Access permissions: `Read & Write`

  Click on `Generate` and copy the secret.
* Store PAT on Jenkins
  * `Manage Jenkins` → `Credentials` → `Add Credentials` → `Username with password`
    * Username: `<your Docker Hub username, as it appears in Docker Hub URL>`
    * Password: `<paste PAT here>`
    * ID: `docker-hub`
    * Description: `Docker Hub`

    Click on *Create*
* Store K3s Kubeconfig file
  * `Manage Jenkins` → `Credentials` → `Add Credentials` → `Secret file`
    * Name: `k3s-kubeconfig`
    * We need to upload a config file. Follow these instructions:
      * Log into K3 master running on AWS EC2 instance
        ```bash
        aws ssm start-session --target $(aws ec2 describe-instances --filters "Name=tag:Name,Values=devops-experts-k3s-master" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text)
        ```
        Now inside the instance terminal copy the content of kubeconfig file
        ```bash
        sudo cat /etc/rancher/k3s/k3s.yaml # In k3 master
        ```
      * Create a file in your host machine and paste kubeconfig content you've just copied.
      * Update the server address to K3s master instance private IP.
        To get the private IP of the instance run
        ```bash
        aws ec2 describe-instances --filters "Name=tag:Name,Values=devops-experts-k3s-master" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PrivateIpAddress" --output text
        ```
      * Select the kubeconfig modified file in Jenkins
* Install plugins:
  * Core/Built-in Plugins (typically installed during initial setup):
    * Pipeline
    * GitHub Branch Source
    * Pipeline: GitHub Groovy Libraries
    * Pipeline Graph View
    * Git
  * Docker Pipeline (enables native `docker.build` and `docker.withRegistry` syntax)
  * Generic Webhook Trigger (used for `Jenkinsfile.merge` file)
  * Pipeline GitHub Notify Step (requires to notify GitHub when a pipeline is running)
  * (Optional) Pipeline: Stage View
  * (Optional) Blue Ocean
* In [/jenkins/Jenkinsfile.pr](/jenkins/Jenkinsfile.pr) and In [/jenkins/Jenkinsfile.merge](/jenkins/Jenkinsfile.merge), update `web-app.params.DOCKER_HUB_REPO` to your Docker Hub `<account name>/<new repository name>`.  
  Commit the change and push to your forked repository.
* Create 2 new jobs:
  1. Job for PR
    * Name: `final-project-pr`
    * Select `Multibranch Pipeline` as the project type and click `OK`
    * In the next screen, under `Branch sources` section, click on *add source* and select *GitHub*
      * Credentials - select `GitHub`
      * Repository URL: `<paste your forked repo URL>`
    * Under `Build Configuration` section,
      * Mode: `by Jenkinsfile`
      * Script Path: `jenkins/Jenkinsfile.pr`

      Click `Save`.

  2. Job for Merge
    * Name: `final-project-merge`
    * Select `Pipeline` as the project type and click `OK`
    * In the next screen, under `Pipeline → Definition` section, select *Pipeline script from SCM*
      * SCM: `Git`
        * Repository URL: `<paste your forked repo URL>`
        * Credentials - select `GitHub`
        * Branch specifier: `*/main`
      * Script Path: `jenkins/Jenkinsfile.merge`

      Click `Save`.
* On the job dashboard page, click `Build Now` to trigger the initial execution.

### Setup GitHub Webhooks
A Webhook means that GitHub sends a request to our Jenkins instance, every time an event occurs (in our case, we will select Pull Request (PR)).  
Jenkins supports GitHub Webhooks by default, but we also use `Generic Webhook Trigger` plugin for the merge pipeline.

* We need to point to our AWS Application Load Balancer (ALB) endpoint.  
  To get the ALB DNS run
  ```bash
  aws elbv2 describe-load-balancers --names devops-experts-alb --query 'LoadBalancers[*].DNSName' --output text
  ```
* Setup Webhooks on your repository  
  Enter your repository on GitHub → `Settings` → `Webhooks`.  
  We need to add 2 webhooks:
  1. Hook for merge - using Generic Webhook Trigger plugin endpoint
    * Payload URL: `http://<ALB DNS>/generic-webhook-trigger/invoke?token=secret-for-j3nk1ns-plugin`  
      *(Notice that here I used a different secret. Explanation on [jenkins-notes.md](./jenkins-notes.md))*
    * Content type: `application/json`
    * Secret: keep empty
    * `Events` - select `Let me select individual events` and choose `Pull Requests`.  

    Click on `Add webhook`.
  2. Hook for PR - using jenkins default endpoint
    * Payload URL: `http://<ALB DNS>/generic-webhook/`  
      *(Notice that here I used a different secret. Explanation on [jenkins-notes.md](./jenkins-notes.md))*
    * Content type: `application/json`
    * Secret: keep empty
    * `Events` - select `Let me select individual events` and choose `Pull Requests`.  

    Click on `Add webhook`.

* Troubleshooting Webhooks instructions: [jenkins-notes.md](./jenkins-notes.md#troubleshooting)
