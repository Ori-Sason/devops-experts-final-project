# Support GitHub Webhooks on Jenkins
A Webhook means that GitHub sends a request to our Jenkins instance, every time an event occurs (in our case, we will select Pull Request (PR)).

* Install `Generic Webhook Trigger` plugin
  Jenkins → `Manage Jenkins` → `Plugins` → `Available plugins` → search for *Generic Webhook Trigger* → `Install`.
* Restart Jenkins by running on the host machine
  ```bash
  docker restart jenkins
  ```
* **If you run Jenkins on EC2 instance** - use the public IP.  

  **If you run Jenkins locally**, we need to expose Jenkins to the internet so GitHub will be able to send requests to it (Webhook). We can do that by using Ngrok, which is a tool that creates a public URL and forwards requests to a process running on our host machine.  
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
  Enter your repository on GitHub → `Settings` → `Webhooks` → `Add webhook`  
  * Payload URL: `<Public IP OR Personal Ngrok URL>/generic-webhook-trigger/invoke?token=secret-for-j3nk1ns-plugin`  
    *(Notice that here I used a different secret. It will be clear soon)*
  * Content type: `application/json`
  * Secret: `this-is-my-G1tHub-little-secret` *(that's the secret we wrote on Ngrok traffic policy file)*
  * `Events` - select `Let me select individual events` and choose `Pull Requests`.  

  Click on `Add webhook`.
* Add the plugin properties at the top of `Jenkinsfile` (sets the trigger)  

  ***NOTE:*** *The following example triggers the job when there is PR opened/reopened/synchronized OR closed by merge. This is **NOT** suitable for the current pipeline, since we build and deploy both Docker image and Helm Chart. Triggering the pipeline twice - once on PR open and again on merge - would result in double publishing.*  
  *This is just an example for what we can do with this plugin.*

  ```groovy
    properties([
        parameters([...]), // Placeholder - define parameters here

        pipelineTriggers([
            GenericTrigger(
                genericVariables: [
                    [key: 'action', value: '$.action'],
                    [key: 'is_pr_merged', value: '$.pull_request.merged'],
                    [key: 'pr_base_sha', value: '$.pull_request.base.sha'],
                    [key: 'pr_head_sha', value: '$.pull_request.head.sha']
                ],
                token: 'secret-for-j3nk1ns-plugin', // Token written on GitHub Settings → Webhooks
                regexpFilterText: '$action $is_pr_merged',
                regexpFilterExpression: '^(opened|reopened|synchronize) false$|^closed true$'
            )
        ])
    ])
  ```
  * You can see we have 2 secrets
    * Ngrok's secret (`this-is-my-G1tHub-little-secret`) is between GitHub and Ngrok (validates request signature)
    * Jenkins's token (`secret-for-j3nk1ns-plugin`) is between Ngrok and Jenkins (identifies which job to trigger)
  * When we do something related to PR, a POST request will be sent to Jenkins, with JSON payload. As part of this request JSON, we have `action` and `merged` fields. We set their names in the the pipeline to `action` and `is_pr_merged`, respectively.  

    If you want to see the payload sent by GitHub: Github repository → `Settings` → `Webhooks` → select our webhook → `Recent Deliveries` → you should a list of all requests.
    We didn't create a request yet, so this list should be empty at this point.
  * Explanation for `regexpFilter`  
    We set a filter based on 2 fields: `$action $is_pr_merged`. That means that there are 2 sections separated by space. Therefore, on `expression` we also need to set a rule based on 2 fields - left one refer to the `action` field and the right one refer to the `is_pr_merged` field.  
    The first rule is `^(opened|reopened|synchronize) false$` - action is `opened/reopened/synchronize` and merge is `false`. So, when a PR opens.  
    Now we have pipe (`|`) as an `OR` operator.  
    Second rule is: `^closed true$` - action is `closed` and `merged` is `true`.
* Update `gitleaks` command in our Jenkinsfile
  ```groovy
  sh """
    gitleaks detect \
      --log-opts='${env.pr_base_sha}'..'${env.pr_head_sha}' \
      --verbose \
      --log-level=debug \
      --redact
  """
  ```
  Here we select only the commits related to that PR/merge. By using Webhooks, we can identify the commits related to the PR and we don't need to scan the whole repository history on every execution.
* Commit the changes and push to GitHub.
* Build the pipeline manually.  
  The `properties()` block, including `genericVariables`, only takes effect after the pipeline runs once. Always trigger a manual build after changing `properties()` before testing via webhook.
* To test that everything works, open a PR to `main` branch. Jenkins should be triggered.
* Troubleshooting  
  On GitHub delivery page (Github repository → `Settings` → `Webhooks` → select our webhook → `Recent Deliveries` → you should a list of all requests. Select you're request) you can see the request and response. By the response you can find if anything was triggered and what variables were sent  
  ```JSON
  {
    "jobs": {
      "pipeline-try2": {
        "regexpFilterExpression": "^(opened|reopened|synchronize) false$|^closed true$",
        "triggered": true,
        "resolvedVariables": {
          "action": "opened",
          "pr_base_sha": "4e53e5fab4671e6380e89801f368668d9d217a6e",
          "pr_head_sha": "0ec4bb0901f9a57f11e0a70e99a1f424f4b7babd",
          "pr_merged": "false"
        },
        "regexpFilterText": "opened false",
        "id": 420,
        "url": "queue/item/420/"
      }
    },
    "message": "Triggered jobs."
  }
  ```

**IMPORTANT:** When we trigger the pipeline manually, the plugin can't inject the variables. This means that we can't know the base and head commits (they will have the value `null`). If your job failed and you want to re-trigger it, do it from GitHub (and not by pressing Jenkins `Replay` button): Github repository → `Settings` → `Webhooks` → select our webhook → `Recent Deliveries` → select your record → `Redeliver`.

* There is an option to Notify GitHub that there is a job running related to a given event (like push or PR). We can do that by using `Pipeline GitHub Notify Step`.  
  By using this plugin we can add another protection layer - for example, blocking PR from being merged until tests are passed.
