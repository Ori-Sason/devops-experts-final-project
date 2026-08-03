# Jenkins installation on local Docker container

To run Jenkins on local machine, follow the instructions on [running-jenkins.md](./running-jenkins.md).

Access Jenkins UI at http://localhost:8080.

If this is your first time deploying Jenkins for this project, you must configure the required authentication credentials and create the pipeline job. Follow this step-by-step setup guide:

* To get the initial administrator password, ru the following command on the terminal
  ```bash
  sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
  ```

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
* In [/jenkins/local.Jenkinsfile.pr](/jenkins/local.Jenkinsfile.pr) and In [/jenkins/local.Jenkinsfile.merge](/jenkins/local.Jenkinsfile.merge), update `web-app.params.DOCKER_HUB_REPO` to your Docker Hub `<account name>/<new repository name>`.  
  Commit the change and push to your forked repository.
* Create 2 new jobs:
  1. Job for PR
     * Name: `final-project-pr`
     * Select `Multibranch Pipeline` as the project type and click `OK`
     * In the next screen, under `Branch sources` section, click on *Add source* and select *GitHub*
       * Credentials - select `GitHub`
       * Repository URL: `<paste your forked repo URL>`
     * Under `Build Configuration` section,
       * Mode: `by Jenkinsfile`
       * Script Path: `jenkins/local.Jenkinsfile.pr`

     Click `Save`.

  2. Job for Merge
     * Name: `final-project-merge`
     * Select `Pipeline` as the project type and click `OK`
     * In the next screen, under `Pipeline → Definition` section, select *Pipeline script from SCM*
       * SCM: `Git`
         * Repository URL: `<paste your forked repo URL>`
         * Credentials - select `GitHub`
         * Branch specifier: `*/main`
       * Script Path: `jenkins/local.Jenkinsfile.merge`

     Click `Save`.  
     On the job dashboard page, click `Build Now` to trigger the initial execution (it will fail since it should be triggered by GitHub Webhook. The purpose is to load the script configuration).
* **On Linux machines** we also need to connect Jenkins Docker container to `minikube` network
  ```bash
  sudo -i -u <host username> docker network connect minikube jenkins
  ```

### Setup GitHub Webhooks
A Webhook means that GitHub sends a request to our Jenkins instance, every time an event occurs (in our case, we will select Pull Request (PR)).  
Jenkins supports GitHub Webhooks by default, but we also use `Generic Webhook Trigger` plugin for the merge pipeline.

* Expose port to the internet with Ngrok  
  Since we run Jenkins locally, we need to expose Jenkins Docker to the internet, so GitHub will be able to send requests to it (Webhook). We can do that by using Ngrok, which is a tool that creates a public URL and forwards requests to a process running on our host machine.  
  In our case, we will expose port `8080` to the internet with Ngrok. GitHub will send requests to Ngrok public address, it will forward it to our local port `8080`, which is running Jenkins.  
  * Install Ngrok on your host machine - [ngrok.com/download](https://ngrok.com/download/) and create an account.
  * Once you're logged to your Dashboard, you will see your personal token.  
    Run on the host machine
    ```bash
    ngrok config add-authtoken "<YOUR_AUTHTOKEN>"
    ```
  * Since we expose our personal machine to the internet, we want to secure the connection and let **only** GitHub send requests to it. For that, create a YAML file (I named mine `github_policy.yml`).

    ```yaml
    on_http_request:
    - actions:
        - type: verify-webhook
          config:
            provider: github
            secret: "this-is-my-G1tHub-little-secret" # Dynamic
    ```
  * Now you can open port `8080` to the internet
    ```bash
    ngrok http 8080 --traffic-policy-file ./github_policy.yml
    ```
    In the output you can see your personal link, made by Ngrok, in `Forwarding` row (you can find the same link on your Ngrok's Dashboard). Every user has it's own static subdomain.
    ```bash
    Forwarding    https://<personal-subdomain>.ngrok-free.dev -> http://localhost:8080  
    ```
* Setup Webhooks on your repository  
  Enter your repository on GitHub → `Settings` → `Webhooks`.  
  We need to add 2 webhooks:
  1. Hook for merge - using Generic Webhook Trigger plugin endpoint
     * Payload URL: `<Public IP OR Personal Ngrok URL>/generic-webhook-trigger/invoke?token=secret-for-j3nk1ns-plugin`  
       *(Notice that here I used a different secret. Explanation on [jenkins-notes.md](./jenkins-notes.md))*
     * Content type: `application/json`
     * Secret: `this-is-my-G1tHub-little-secret` *(that's the secret we wrote on Ngrok traffic policy file)*
     * `Events` - select `Let me select individual events` and choose `Pull Requests`.  

     Click on `Add webhook`.
  2. Hook for PR - using jenkins default endpoint
     * Payload URL: `<Public IP OR Personal Ngrok URL>/github-webhook/`  
       *(Notice that here I used a different secret. Explanation on [jenkins-notes.md](./jenkins-notes.md))*
     * Content type: `application/json`
     * Secret: `this-is-my-G1tHub-little-secret` *(that's the secret we wrote on Ngrok traffic policy file)*
     * `Events` - select `Let me select individual events` and choose `Pull Requests`.  

     Click on `Add webhook`.

* Troubleshooting Webhooks instructions: [jenkins-notes.md](./jenkins-notes.md#troubleshooting)
