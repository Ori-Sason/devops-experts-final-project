# Traffic Generator CronJob

This Kubernetes CronJob automates the generation of synthetic traffic to the application.

## Overview
The CronJob runs a lightweight `busybox` container every **2 minutes**. It executes a shell script that:
1.  Defines targeted endpoints: `/` (Home) and `/visits`.
2.  Generates a **random number** (0-9) for each endpoint individually.
3.  Sends internal `GET` requests using `wget` to the `web-svc` service.

By using internal service discovery (`http://web-svc`), the traffic stays within the cluster network, simulating real user interaction.

---

## How to Manually Trigger
While the CronJob is scheduled to run every 2 minutes, you can manually trigger a "one-off" execution for testing purposes without waiting for the next schedule.

1. Create a Job from the CronJob
Run the following command to create a manual Job based on the CronJob template:
```bash
kubectl create job --from=cronjob/traffic-generator manual-traffic-run
```

2. Inspect Logs
To see how many requests were sent during the manual run, check the logs of the generated pod:

```bash
kubectl logs -l job-name=manual-traffic-run
```

3. Cleanup
After verifying the results, you can remove the manual job:

```bash
kubectl delete job manual-traffic-run
```

Note: Ensure that the `web-svc` service is running and healthy before triggering, as the script relies on internal cluster DNS resolution.