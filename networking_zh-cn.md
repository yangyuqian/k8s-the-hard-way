# Kubernetes集群中的网络

网络是Kubernetes\(下称k8s\)集群中的关键组成部分，本文借助一个简单的例子，分析了Kubernetes集群中的网络组成以及相互之间的联系，希望对其他的解决方案有一些启发.

> 本文假设读者对Linux Kernel中虚拟网桥和iptables已经有一定的了解

k8s要求网络解决方案满足以下条件（参见：[k8s网络模型](https://kubernetes.io/docs/admin/networking/#kubernetes-model)）：

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

> 注意下面“在集群内”的命令都需要attach到一个Pod里面才可以执行
>
> ```
> kubectl run --rm -it curl --image="docker.io/appropriate/curl" sh
> ```

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

图1 上面例子的网络图解（采用flannel来搭建overlay network）

![](/assets/k8s-network \(1\).png)

> 总结：
>
> 1. kube-proxy并不承担实际的流量转发工作，实际上它会从kube-apiserver动态拉取最新的应用与服务状态信息，并在本机上生成iptable规则，即使把kube-proxy停掉，已经生成的规则还是可用的.
> 2. Service到Pod的流量完全在本机网络中完成，简单而不失高效.
> 3. Service对多个Pod进行流量转发时，采用iptable规则来进行负载均衡. 上面的例子中，iptable会在两个Pod中进行分别50%概率的流量转发.
> 4. 本文中介绍iptable转发时提到"iptable转发"，严格意义上措辞不准确，因为iptables只是用数据库维护了一堆kernel中netfilter的hook，这里的表述是为了便于理解.



