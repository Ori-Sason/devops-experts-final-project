# FIX - Make a normal installation guide
```bash
terraform -chdir=./terraform apply

# Copies kubeconfig file from EC2 to local
aws ssm start-session --target $(aws ec2 describe-instances --filters "Name=tag:Name,Values=devops-experts-k3s-master" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text)
sudo cat /etc/rancher/k3s/k3s.yaml # in k3 master
exit

vim ~/.kube/config # paste the content of the file


### Session for running kubectl commands locally
aws ssm start-session \
    --target $(aws ec2 describe-instances --filters "Name=tag:Name,Values=devops-experts-k3s-master" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text)  \
    --document-name AWS-StartPortForwardingSession \
    --parameters '{"portNumber":["6443"],"localPortNumber":["6443"]}'

# from now on you can use `kubectl` in your terminal

### Install external-secrets for connecting to AWS RDS
helm repo add external-secrets https://charts.external-secrets.io

# Update ./terraform/secrets-auto-tfvars.example
# 1. Fill in username and password for the DB master user
# 2. rename the file to: ./terraform/secrets.auto.tfvars
# Then continue with the following commands

helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace

### Installing web-app Helm Chart
helm install app ./helm-chart/visit-counter -f ./helm-chart/visit-counter/values-prod.yaml

# Prints ALB DNS
echo http://$(aws elbv2 describe-load-balancers --names devops-experts-alb --query 'LoadBalancers[*].DNSName' --output text):80
# Now you can browse to http://<ALB DNS>:80 to see the app


### Installing monitoring Helm Chart
helm dependency update ./helm-chart/monitoring

helm install monitoring ./helm-chart/monitoring/ \
    -f ./helm-chart/monitoring/values-prod.yaml \
    --namespace monitoring \
    --create-namespace

kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80

aws ssm start-session \
    --target $(aws ec2 describe-instances --filters "Name=tag:Name,Values=devops-experts-k3s-monitoring" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text) \
    --document-name AWS-StartPortForwardingSession \
    --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'

# Now you can browse to http://localhost:3000 to see Grafana UI


### Uninstall
helm uninstall monitoring --namespace monitoring
helm uninstall app
helm uninstall external-secrets --namespace external-secrets
kubectl delete namespace external-secrets

terraform -chdir=./terraform destroy
```
