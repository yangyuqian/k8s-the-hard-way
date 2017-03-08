# Kubernetes集群中的网络

网络是Kubernetes\(下称k8s\)集群中的关键组成部分，k8s要求网络解决方案满足以下条件（参见：[k8s网络模型](https://kubernetes.io/docs/admin/networking/#kubernetes-model)）：

* 容器之间不需要NAT，直接可见

* 节点和容器之间不需要NAT，直接可见

* 容器内部使用的IP应该和外部暴露的IP一致

实际上，Kubernetes网络应该由2部分组成：

* k8s网络模型实现：如Overlay Network\(第三方实现中有Flannel，Contiv等\)
* 集群内IP\(Cluster IP\)，用以集群内服务发现，DNS解析等

为了说明k8s集群网络，下面部署一个nginx服务，同时部署了2个pod:

```
$ kubectl create -f https://raw.githubusercontent.com/yangyuqian/k8s-the-hard-way/master/assets/nginx.yaml

deployment "nginx-deployment" created
service "nginx-service" created
```

可以直接在主机上用pod的IP来访问对应的Pod:

```
$ kubectl get pod --selector="app=nginx" -o jsonpath='{ .items[*].status.podIP }'

172.30.40.3 172.30.98.4

$ curl 172.30.40.3:80
...

$ curl 172.30.98.4:80
...
```

也可以在集群内，使用Cluster IP来访问服务：

```
$ kubectl get services
NAME            CLUSTER-IP       EXTERNAL-IP   PORT(S)                               AGE
kubernetes      10.254.0.1       <none>        443/TCP                               1d
nginx-service   10.254.126.60    <none>        8000/TCP                              9m

$ kubectl run --rm -it curl --image="docker.io/appropriate/curl" sh

$ curl 10.254.126.60:8000
...
```

如果部署了DNS服务，那么还可以通过集群内的域名来访问对应的服务：

```
$ curl nginx-service:8000
...
```

Figure 1 shows the network of above example\(use flannel to build the overlay network\)

![](/assets/k8s-network \(1\).png)

Pods are connected through overlay network, and iptable rules are created dynamically by kube-proxy, traffic to services will be dispatched to the pod IP in the overlay network; The DNS server is also updated dynamically and resolve domains into the virtual cluster IPs.

Note that kube-proxy doesn't dispatch traffic for Services-Pods, instead, it generates iptable rules and the kernel will handle data forwarding.

Technically, you can stop the kube-proxy and iptable rules are kept unchanged, so Services will be still available.



