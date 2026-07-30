## Run Jenkins
* To run Jenkins I used `jenkins/jenkins:lts-jdk21` image.  
  To run it locally, run `jenkins/docker-compose.yaml` file:
  * On MacOS / Linux:
    ```bash
    DOCKER_GID=$(stat -f "%g" /var/run/docker.sock) docker compose -f ./jenkins/docker-compose.yaml up -d
    ```
    In Linux, replace `stat -f` with `stat -c`.
  * On Windows (assuming you run Docker on WSL2):  
    Run on PowerShell
    ```powershell
    $env:DOCKER_GID=0; docker compose -f .\jenkins\docker-compose.yaml up -d
    ```

Access Jenkins UI at http://localhost:8080.

* If this is your first time deploying Jenkins for this project, you must configure the required authentication credentials and create the pipeline job. Follow the step-by-step setup guide in [jenkins-installation.md](./jenkins-installation.md).

## Explanation
To run a Docker Daemon, Linux requires very deep, low-level kernel privileges (like managing cgroups, iptables firewall rules, and mounting filesystems). Regular containers (like the standard Jenkins container) are locked down and isolated from the host kernel for security. They are physically blocked from starting a Docker Daemon.  

We run Jenkins in a Docker container. As part of the image building process, we install the Docker package, which includes both Docker Daemon and Docker CLI (to use Docker commands in the pipeline).  
If we would try to start Docker process, Docker Daemon would fail, because of low privileges (explained above), and we left only with Docker CLI available.  
This is why I've pulled only Docker CLI to the final stage
```Dockerfile
COPY --from=downloader /tmp/docker/docker /usr/local/bin/docker
```  

At this point, when we run Docker commands in our pipeline, they fail since there is no Docker Daemon connected.  
To solve that I've used the host machine daemon.
1. I used bind mount host's daemon into the container.  
  In Docker Compose, look for volume `/var/run/docker.sock:/var/run/docker.sock`.  
  So, the container is directed to the socket of the host's Docker Daemon.
2. We need to give the container permissions to use the host's `docker.sock`.  
    To understand how it works, let's run `ls -la /var/run/docker.sock` **on the host machine**.  
    If we use **Linux / MacOS**, we get
    ```bash
    srw-rw---- 1 root docker 0 /var/run/docker.sock
    ```
    This means that on the host machine, `root` user and `docker` group are allowed to read and write to the demon's socket.  
    As explained before, this exact file is now in use by our Jenkins container, since we bind mount it.  

    Last background point: the kernel doesn't care about the group name, it checks permissions by the group ID. To get Docker's group ID, we can run
    ```bash
    stat -f "%g" /var/run/docker.sock # Works on MacOS. Change `-f` to `-c` on Linux
    ```
    For the following explanation, let's say we got group ID `998`.

    Now, to the Jenkins container. The pipelines run on `jenkins` user. When we use Docker commands on our pipeline, it reach `docker.sock`, which again, is the host's socket. Now, the host's kernel checks whether the process's UID/GIDs have permission to access the socket. Since it doesn't, it fails.  

    To solve that, we will add `jenkins` to a group with the same ID number as the host's `docker` group (in our example, `998`).
    ```bash
    groupadd -g 998 host-docker && usermod -aG host-docker jenkins
    ```
    Now, Jenkins belongs to group `998`. So, when it asks for using `docker.sock`, the host's kernel sees that "someone" belongs to group `998` asked to use this file, and accepts the call.
    So, the workaround add `jenkins` user to a group with the same ID as the one running `docker.sock` on the host machine.

    To make things easy, instead of running a command on the host machine to get Docker's group ID and update `docker-compose.yaml`, we inject it into a dynamic variable in Compose file
    ```yaml
      group_add:
        - "${DOCKER_GID}"
    ```
    ```bash
    `DOCKER_GID=$(stat -f "%g" /var/run/docker.sock) docker compose -f .\jenkins\docker-compose.yaml up -d`
    ```

* We talked about MacOS and Linux, but why we use group `0` (root) on **Windows WSL2**?  
  To get the permissions of `docker.sock` file, run in PowerShell
  ```Powershell
  wsl -- stat -c "%g" /var/run/docker.sock
  ```
  We get a number, like `1001` (equivalent to `998`).  
  Now, if we log into the container and run the same command
  ```bash
  docker exec -u root -it jenkins sh

  # Now we are inside the container
  stat -c "%g" /var/run/docker.sock
  ```
  This one returns `0`.  
  The numbers are different - meaning Docker Desktop is genuinely remapping the GID when proxying the socket into the container.
  ```bash
  WSL2:      root:docker  (GID 1001)
  Container: root:root    (GID 0)
  ```
  Docker Desktop translates GID `1001` to `0` when serving the socket into the container.  
  This is because Docker Desktop on Windows passes the socket through multiple abstraction layers (Hyper-V → Docker Desktop VM → WSL2 → container), and the GID gets remapped in the process. This behavior is specific to Docker Desktop on Windows and doesn't happen on native Linux.

  Since we know for sure that we need `root` group, we can hard code `group_add` value to Docker Compose file
  ```powershell
  $env:DOCKER_GID=0; docker compose -f .\jenkins\docker-compose.yaml up -d
  ```

## Alternative (DinD - Docker in Docker)
For security reasons, exposing the host machine's Docker Daemon to Jenkins is a massive risk. A much safer alternative is running an isolated "side-car" container next to Jenkins that runs its own independent Docker Daemon, and connecting Jenkins to it ([Jenkins Docs](https://www.jenkins.io/doc/book/installing/docker/)).

First, we run the sidecar
```bash
docker run \
  --name jenkins-docker \
  --rm \
  --detach \
  --privileged \
  --network jenkins \
  --network-alias docker \
  --env DOCKER_TLS_CERTDIR=/certs \
  --volume jenkins-docker-certs:/certs/client \
  --volume jenkins-data:/var/jenkins_home \
  --publish 2376:2376 \
  docker:dind \
  --storage-driver overlay2
```
`docker-dind` is a container running Docker Daemon. We said that a container doesn't have permissions to run Docker Daemon - for that we use `--privileged` option.  
Notice that we add this container to `jenkins` network.

Next, we should run our Jenkins container
```bash
docker run \
  --name jenkins \
  --restart=on-failure \
  --detach \
  --network jenkins \
  --env DOCKER_HOST=tcp://docker:2376 \
  --env DOCKER_CERT_PATH=/certs/client \
  --env DOCKER_TLS_VERIFY=1 \
  --publish 8080:8080 \
  --publish 50000:50000 \
  --volume jenkins-data:/var/jenkins_home \
  --volume jenkins-docker-certs:/certs/client:ro \
  jenkins/jenkins:lts-jdk21
```
By placing Jenkins on the same `jenkins` network and sharing the TLS certificates via a volume, the two containers can communicate securely.  
Now, whenever you execute a `docker` CLI command inside the Jenkins container, the environment variable `DOCKER_HOST=tcp://docker:2376` forces it to route that request over a secure TCP connection straight to the sidecar's daemon instead of looking for a local host socket.

### Which approach to choose?
It's a tradeoff between security and performance.  
With the side-car pattern, if an attacker compromises your Jenkins instance, the blast radius is contained. They can only manipulate the isolated sidecar container; they cannot escape onto the physical host machine.

However, using DinD approach can hurt the performance. The overhead comes from nested layering - Docker commands inside Jenkins are hitting a containerized daemon, which itself runs inside Docker, adding virtualization overhead.


## From Claude - 2 more approaches and a summary
### Option 1 - Install both, Jenkins and Docker, on a VM (Bare Metal / Native)

Install Jenkins directly on the host, install Docker, and add the `jenkins` user to the `docker` group.

**Pros:**
- Simplest setup, easiest to debug
- No Docker socket sharing complexity
- Best raw performance - no container overhead
- Full access to Docker Daemon natively
- Helm and Docker CLI work out of the box

**Cons:**
- Harder to reproduce environments ("works on my machine" problem)
- Jenkins and its dependencies pollute the host
- Scaling and migration are painful
- Not cloud-native; harder to manage as infrastructure-as-code

**Best for:** Small teams, hobby projects, self-hosted on a single VM where simplicity matters more than portability.

---

### Option 2 - Jenkins Container + Docker-in-Docker (DinD) Sidecar

The official Jenkins docs recommend running a `docker:dind` container alongside Jenkins on the same Docker network, with Jenkins using the DinD daemon instead of the host's.

**Pros:**
- Fully isolated Docker environment per run (clean builds)
- Closer to production parity
- Jenkins itself is containerized and reproducible
- Official and documented approach

**Cons:**
- Requires running the DinD container in `--privileged` mode, which is a significant security concern - a compromised build can escape to the host
- More complex networking and TLS cert management
- Performance overhead from nested virtualization
- Image layer caching doesn't persist well between builds without extra volume configuration

**Best for:** Isolated CI environments where build cleanliness is critical and you accept the privileged container tradeoff.

---

### Option 3 - Jenkins Container + Docker Socket Mounting (`/var/run/docker.sock`)

Mount the host's Docker socket directly into the Jenkins container:

```bash
-v /var/run/docker.sock:/var/run/docker.sock
```

This lets Jenkins control the host's Docker Daemon directly.

**Pros:**
- Much simpler than DinD - no sidecar container needed
- No `--privileged` flag on the Jenkins container
- Fast - uses host's Docker directly, so layer caching works great
- Widely used and well understood

**Cons:**
- Security risk: giving a container access to the Docker socket is effectively giving it root on the host. A malicious or compromised pipeline job could escape the container entirely
- Containers built in pipelines are siblings (not children) of the Jenkins container, which can cause path/volume confusion
- Not truly isolated - a bad build can affect the host system

**Best for:** Internal/trusted environments where developer convenience and speed outweigh security concerns. Very popular for local dev CI setups.

---

### Option 4 - Jenkins on Kubernetes (the modern industry standard)

Run Jenkins on a Kubernetes cluster using the Kubernetes plugin. Each build spins up a fresh pod, runs the job, and is destroyed. For Docker builds, use Kaniko or Buildah (daemonless image builders that don't need Docker at all).

**Pros:**
- No Docker Daemon required - Kaniko/Buildah build OCI-compliant images without root or privileged containers
- Elastic scaling - pods spin up/down per job, no idle agents
- True isolation - every build is a clean ephemeral environment
- Cloud-native, GitOps-friendly
- Helm chart testing fits naturally (just run `helm test` in a pod)
- Industry standard for teams at scale

**Cons:**
- Significantly more complex to set up initially
- Requires a Kubernetes cluster (though k3s/kind work locally)
- Kaniko/Buildah have a learning curve vs. plain `docker build`
- Overkill for small solo projects

**Best for:** Production-grade CI/CD at any meaningful team scale.

---

### Side-by-Side Comparison

| | VM (Option 1) | DinD (Option 2) | Socket Mount (Option 3) | Kubernetes (Option 4) |
|---|---|---|---|---|
| **Security** | ✅ Good | ⚠️ Privileged | ⚠️ Root equiv. | ✅ Best |
| **Simplicity** | ✅ Easiest | 🔶 Medium | ✅ Easy | ❌ Complex |
| **Isolation** | ❌ None | ✅ Full | ❌ Shares host | ✅ Full |
| **Performance** | ✅ Best | 🔶 Overhead | ✅ Good | 🔶 Pod startup |
| **Scalability** | ❌ Manual | 🔶 Limited | 🔶 Limited | ✅ Auto |
| **Industry use** | 🔶 Legacy | 🔶 Common | ✅ Very common | ✅ Modern standard |
| **Helm support** | ✅ Native | ✅ Yes | ✅ Yes | ✅ Native |

---

### Recommendation

Since you need Docker builds + Docker Hub pushes + Helm chart testing, here's what's suggested based on context:

- **Starting out / single VM:** Go with **Option 3** (socket mount). It's the pragmatic sweet spot - simple, fast, well-documented, and widely used. Just be aware of the security tradeoff and lock down who can trigger builds.
- **Team environment / production:** Go with **Option 4** (Kubernetes + Kaniko). It's what most serious CI pipelines use today. Kaniko handles `docker build` + `docker push` without any daemon, and Helm testing is a natural fit in pods.
- **Avoid Option 2** (DinD) unless you have a specific reason to want fully isolated Docker Daemons - the privileged container risk usually isn't worth it compared to socket mounting, which is simpler and nearly as capable.
