# Networking

Networking is one of the most important part in a Kubernetes cluster, and you can choose your own networking solution, which implementing the [network model](https://kubernetes.io/docs/admin/networking/#kubernetes-model).

* Containers can reach each other without NAT

* Nodes can reach all containers running on them without NAT

* Container sees a similar IP that others see

In Kubernetes, there are mainly two parts of network:

* An overlay network, provided by 3rd party implementations, such as Flannel and Contiv
* A virtual network, known as Cluster IPs, which can be resolved from a built-in DNS service

To clarify network in Kubernetes, let's deploy a nginx Service connected to 2 Pods:

```
$ kubectl create -f https://raw.githubusercontent.com/yangyuqian/k8s-the-hard-way/master/assets/nginx.yaml

deployment "nginx-deployment" created
service "nginx-service" created
```

The created pods are accessible through the IPs offered by the overlay network:

```
$ kubectl get pod --selector="app=nginx" -o jsonpath='{ .items[*].status.podIP }'

172.30.40.3 172.30.98.4

$ curl 172.30.40.3:80
...

$ curl 172.30.98.4:80
...
```

It's also available through the cluster ip provided by kubernetes:

```
$ kubectl get services
NAME            CLUSTER-IP       EXTERNAL-IP   PORT(S)                               AGE
kubernetes      10.254.0.1       <none>        443/TCP                               1d
nginx-service   10.254.126.60    <none>        8000/TCP                              9m

$ kubectl run --rm -it curl --image="docker.io/appropriate/curl" sh

$ curl 10.254.126.60:8000
...
```

And, domain of nginx-service is accessible inside the cluster:

```
$ curl nginx-service:8000
...
```

Figure 1 shows the network of above example\(use flannel to build the overlay network\)

![](/assets/k8s-network \(1\).png)

Pods are connected through overlay network, and iptable rules are created dynamically by kube-proxy, traffic to services will be dispatched to the pod IP in the overlay network; The DNS server is also updated dynamically and resolve domains into the virtual cluster IPs.

Note that kube-proxy doesn't dispatch traffic for Services-Pods, instead, it generates iptable rules and the kernel will handle data forwarding.

Technically, you can stop the kube-proxy and iptable rules are kept unchanged, so Services will be still available.

