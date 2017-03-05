# Infrastructure

OS

```
$ cat /etc/centos-release
CentOS Linux release 7.3.1611 (Core)

$ uname -r
3.10.0-327.36.3.el7.x86_64
```

Kubernetes: v1.5.3

Networking: Flannel

Container Engine: Docker

DNS: SkyDNS

# Preparison

Check out you infrastructure:

> Can you access hosts in your cluster with root?

* No? Go to your administrator for the root account.

> Are hosts in the cluster visible to each other by domain?

* No? [Setup Hosts for Cluster](#setuphosts)

> Is any firewall running on those hosts?

* Yes? [Disable Firewalls](#disablefirewall)

## Setup Hosts for Cluster {#setuphosts}



## Disable Firewalls {#disablefirewall}



