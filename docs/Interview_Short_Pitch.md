# ⏱️ 3-Minute Interview Pitch: Kubernetes Automation Project

> **How to use this:** This is your "script" when the interviewer asks: *"Explain your CDAC project to me."* It’s designed to be spoken aloud and takes about 2–3 minutes. It hits all the keywords they want to hear without overwhelming them.

---

## 🎤 The Pitch (Read this section as your answer)

"For my project, I built a **fully automated, production-ready Kubernetes cluster** from scratch. 

My main goal was to eliminate manual setup errors and create an environment that reflects real-world enterprise standards—specifically focusing on Security and Observability.

I used **Ansible** to automate the entire provisioning process. With just one command (`ansible-playbook site.yml`), my automation configures two Ubuntu VMs, installs the **containerd** runtime, initializes the cluster using `kubeadm`, and sets up **Flannel** for the pod network overlay. 

Instead of just getting a raw cluster, my automation goes several steps further and deploys a complete ecosystem on top of it:

1. **First, Storage:** I configured an external **NFS server**. The playbook automatically creates the StorageClasses, PVs, and PVCs so applications have persistent data that survives pod restarts.
2. **Second, Observability:** I deployed the full **Prometheus and Grafana** stack, along with Node Exporter and Kube-State-Metrics. This gives me real-time dashboards for CPU, memory, and cluster health.
3. **Third, Security (The most important part):** I implemented a Defense-in-Depth approach:
   - At the **Host layer**, Ansible configures UFW firewalls and applies CIS benchmarks.
   - At the **Cluster layer**, I implemented ServiceAccount RBAC and Pod Security Standards to block privileged containers.
   - At the **Network layer**, I wrote default-deny Network Policies to implement Zero-Trust networking.
   - And at the **Runtime layer**, I deployed **Falco** to monitor system calls and detect any suspicious activity, like someone spawning a shell inside a container.
4. **Finally, Autoscaling & Self-Healing:** To prove the cluster works, I deploy an Nginx application with Liveness/Readiness probes. I also configured **HPA (Horizontal Pod Autoscaler)** with a metrics-server to automatically scale the application out when CPU usage spikes.

**To summarize:** I didn't just 'install Kubernetes'. I wrote Infrastructure-as-Code to orchestrate a highly secure, auto-scaling, and fully monitored cluster that could survive a node failure and recover its own data from NFS backups."

---

## 🎯 The 5 Follow-Up Questions to Expect

If you deliver that pitch, the interviewer will likely pull from what you just said. Here are the 5 quickest answers to memorize:

**1. "Why Ansible instead of Terraform?"**
*Answer:* "Because I was configuring bare-metal Ubuntu VMs, not provisioning cloud infrastructure like AWS EC2s. Ansible is agentless, uses SSH, and is perfect for OS-level configuration and installing packages like kubeadm."

**2. "Why containerd instead of Docker?"**
*Answer:* "Kubernetes deprecated Docker as a runtime in v1.24. Containerd is the industry-standard CRI (Container Runtime Interface). It’s lighter weight (around 50MB) and faster because it doesn't have the extra Docker desktop overhead."

**3. "How did you implement Zero-Trust networking?"**
*Answer:* "I wrote Network Policies that use a `default-deny` rule for both ingress and egress on the default namespace. If a pod needs to talk to the internet or another pod, I have to explicitly write an 'allow' rule for that specific port, like allowing port 8080 for Nginx."

**4. "What exactly does Falco do?"**
*Answer:* "Falco is a runtime security tool. It runs as a DaemonSet and uses eBPF to monitor Linux system calls. If a container starts doing something weird—like trying to read the `/etc/shadow` file or dropping a bash shell—Falco detects it immediately."

**5. "How does your storage survive a crash?"**
*Answer:* "My pods don't use local `hostPath` storage. They mount a PersistentVolumeClaim (PVC) that maps to an external NFS server over the network. If a worker node dies, Kubernetes reschedules the pod to the master node, and it simply remounts the exact same NFS directory so no data is lost."
