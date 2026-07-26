# Jenkins Installation

* Generate **GitHub** Personal Access Token (PAT)
  * Fork my repository
  * Create GitHub PAT
    * Profile menu → `Settings` → `Developer Settings` (sidebar menu) → `Fine-grained tokens` (sidebar menu) → `Generate new token`
      * Token name: `jenkins`
      * Expiration: `7 days` (or your preferred duration)
      * Repository access: Select `Only select repositories` and choose your forked repository.
      * Permissions:
        * `Contents` - read and write
        * `Metadata` (automatically added by selecting `Contents`) - read-only

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
  * (Optional) Pipeline: Stage View
  * (Optional) Blue Ocean
* In [/jenkins/Jenkinsfile](/jenkins/Jenkinsfile), update `web-app.params.DOCKER_HUB_REPO` to your Docker Hub `<account name>/<new repository name>`.  
  Commit the change and push to your forked repository.
* Create new job
  * Name: `final-project-pipeline`
  * Select `Pipeline` as the project type and click `OK`
  * In the next screen, under `Pipeline → Definition` section, select *Pipeline script from SCM*
    * SCM: `Git`
      * Repository URL: `<paste your forked repo URL>`
      * Credentials - select `GitHub`
      * Branch specifier: `*/main`
    * Script Path: `jenkins/Jenkinsfile`

  Click `Save`.
* On the job dashboard page, click `Build Now` to trigger the initial execution.
