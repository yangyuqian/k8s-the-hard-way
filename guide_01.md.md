# Infrastructure

OS

```
$ cat /etc/centos-release
CentOS Linux release 7.3.1611 (Core)

$ uname -r
3.10.0-327.36.3.el7.x86_64
```

Kubernetes: v1.5.3

Networking: Flannel\(Overlay\)

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

In case there is no DNS support for your hosts, you can add a custom domain to their /etc/hosts as work around

```
$ cat <EOF > /etc/hosts
<master-ip> <master-domain>
<minion-1-ip> <minion-1-domain>
...
<minion-N-ip> <minion-N-domain>
EOF
```

## Disable Firewalls {#disablefirewall}

On CentOS 7, Selinux is enabled by default, disable it to get rid of unexpected errors

```
$ setenforce 0
```

Stop firewalls

```
$ systemctl disable iptables-services firewalld
...
$ systemctl stop iptables-services firewalld
...
```



