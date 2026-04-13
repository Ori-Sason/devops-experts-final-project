I've followed the walkthrough in K8s documentation
[HorizontalPodAutoscaler Walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)


## Install Metrics server add on
```bash
minikube addons enable metrics-server
```

We need to install the add-on because K8s needs to track the usage of the Pod and compare it to the **request** (not the limit) of the Pod, defined in the Deployment.
If we don't install the add-on, the container "ceiling" will be the Node CPU, while nothing tracks it. K8s is able to track and compare to the request ceiling only with the add-on.

<u>Gemini rephrased in other words</u>:<br/>
You need the add-on because the **Metrics Server** acts as the "thermometer" that reports actual usage to Kubernetes. Without it, the HPA is "blind" to how much CPU the pod is consuming relative to its **request**. While the node's total CPU remains the physical "ceiling," Kubernetes can only track and scale against your defined "request ceiling" if the add-on is there to provide the data.

## To stress the web-app pods
Run the following command
```bash
kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://web-svc/stress; done"
```
This will create small-sized containers that will send a request to our web-app */stress* endpoint.
Each time we send a request, the endpoint will loop for 5,000 times, creating a SHA-256 string our of random 1024 bytes. This process, triggered over and over, will stress the CPU of the node containing the pod.

After a while, on another terminal, run
```bash
kubectl get pods
```

And notice that the number of web-app pods increased from 1, up to 5.

Remember to stop stressing the CPU by stopping with terminal running `load-generator` container.