# Networking

Networking is one of the most important part in a Kubernetes cluster, and you can choose your own networking solution, which implementing the [network model](https://kubernetes.io/docs/admin/networking/#kubernetes-model).

* Containers can reach each other without NAT

* Nodes can reach all containers running on them without NAT

* Container sees a similar IP that others see

Generally, this network model defines a layer 2 connectivity among nodes in your cluster, and it can be achieved by

* Overlay network
* Physical layer 2 to connectivity

This guide will go through some implementations of the overlay network.

## Solutions

There are many solutions implement the [network model](https://kubernetes.io/docs/admin/networking/#kubernetes-model) defined by Kubernetes, and following are in-depth introduction on some of them:

* [Flannel](/overlay-networking/flannel.md)



