# Remote installation on AWS

## Requirements
1. AWS CLI ([Installation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)).
2. AWS CLI Session Manager ([Installation](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)).
3. Terraform ([Installation](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)).

## Running commands
* Create AWS S3 bucket for Terraform backend
  * Browse to [AWS S3 page](https://us-east-1.console.aws.amazon.com/s3/home?region=us-east-1#).  
    Notice that I chose to run my cluster on N. Virginia region (`us-east-1`). If you want to replace the region you'll need to update Terraform code ([backend.tf](/terraform/backend.tf) and [vars.tf](/terraform/vars.tf)) and Helm Chart values ([values-prod.md](/helm-chart/visit-counter/values-prod.yaml)).
  * Click on `Create bucket`
    *	Bucket type: General purpose
    *	Bucket name: `devops-experts-final-project`  
      In case the bucket name is not available or you want to change it, update [backend.tf](/terraform/backend.tf).
    *	Object ownership: ACLs disabled
    *	Block Public Access settings for this bucket: Block all public access (we will change to public after creating the logs bucket)
    *	Bucket versioning: disable
    * Tags:
      * Name: devops-experts-s3
      * Project: devops-experts-final-project

    Click on `Create bucket`.
* (Optional) Instead of storing AWS secrets locally on `~/.aws/credentials`, AWS offers short-term tokens by using Browser authentication.  
    ```bash
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_CREDENTIAL_EXPIRATION
    aws login # Re-authenticate with the browser
    eval $(aws configure export-credentials --profile default --format env)
* Install terraform cluster on AWS
  ```bash
  terraform -chdir=./terraform apply
  ```
* To use `kubectl` commands on local machine
  * Copy K3s master kubeconfig file from remote machine
    ```bash
    aws ssm start-session --target $(aws ec2 describe-instances --filters "Name=tag:Name,Values=devops-experts-k3s-master" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text)

    # Next 2 commands in K3s master node
    sudo cat /etc/rancher/k3s/k3s.yaml # Copy the content
    exit
    ```
  * Paste the content in `~/.kube/config` (on your local machine)
  * Start SSM session
    ```bash
    aws ssm start-session \
        --target $(aws ec2 describe-instances --filters "Name=tag:Name,Values=devops-experts-k3s-master" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text)  \
        --document-name AWS-StartPortForwardingSession \
        --parameters '{"portNumber":["6443"],"localPortNumber":["6443"]}'
    ```
  From now on you can use `kubectl` in your local terminal.
* Configure DB secrets to run AWS RDS
  * Install `external-secrets` chart repository
    ```bash
    helm repo add external-secrets https://charts.external-secrets.io
    ```
  * Update `./terraform/secrets-auto-tfvars.example` file
    1. Fill in username and password for the DB master user
    2. Rename the file to: `./terraform/secrets.auto.tfvars`
  * Install `external-secrets` on K3s cluster
    ```bash
    helm install external-secrets external-secrets/external-secrets \
        -n external-secrets \
        --create-namespace \
        --set-string nodeSelector."node-role\.kubernetes\.io/control-plane"=true
    ```
* Installing `web-app` Helm Chart
  ```bash
  helm install app ./helm-chart/visit-counter -f ./helm-chart/visit-counter/values-prod.yaml
  ```
* Print URL to Application Load Balancer (ALB) endpoint
  ```bash
  echo http://$(aws elbv2 describe-load-balancers --names devops-experts-alb --query 'LoadBalancers[*].DNSName' --output text):80
  ```

  Now you can browse to `http://<ALB DNS>:80` to see the app.
* Installing monitoring Helm Chart
  * Add chart repository
    ```bash
    helm dependency update ./helm-chart/monitoring
    ```
  * Install chart on K3s cluster
    ```bash
    helm install monitoring ./helm-chart/monitoring/ \
        -f ./helm-chart/monitoring/values-prod.yaml \
        --namespace monitoring \
        --create-namespace
    ```
  * Port forward service to pod's host machine (EC2 instance)
    ```bash
    kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
    ```
  * Start SSM session
    ```bash
    aws ssm start-session \
        --target $(aws ec2 describe-instances --filters "Name=tag:Name,Values=devops-experts-k3s-monitoring" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text) \
        --document-name AWS-StartPortForwardingSession \
        --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'
    ```

  Now you can browse to http://localhost:3000 to see Grafana UI.

  * You will be asked to enter username and password
    * Username: `admin`
    * Password: run the following command and copy the password
      ```bash
      kubectl get secret --namespace monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
      ```

* To install Jenkins, follow the instructions on [jenkins-installation-aws.md](/MDs/jenkins/jenkins-installation-aws.md).

## Uninstall
```bash
helm uninstall monitoring --namespace monitoring
helm uninstall app
helm uninstall external-secrets --namespace external-secrets
kubectl delete namespace external-secrets

terraform -chdir=./terraform destroy
```
