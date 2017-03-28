## vxlan在Flannel中的Overlay网络的实现

Flannel\(v0.7+\)支持接入不同的`backend`来搭建Overlay网络，如:

* udp
* vxlan
* alloc
* host-gw
* aws-vpc
* gce
* ali-vpc

其中`host-gw`, `aws-vpc`, `gce`以及`ali-vpc`都需要L2网络层的支持，  
如果没有接入云服务，通常维护成本也比较高.

`alloc`只为本机创建subnet，在多个主机上的虚拟子网不能直接通信.

本文将介绍对平台和协议耦合最低的两个方案之一： `vxlan`的原理及在Flannel中的实现，  
包含以下内容：

* vxlan简介
* Linux内核的vxlan支持
* Flannel中vxlan backend实现

# vxlan简介

[vxlan\(Virtual eXtensible Local Area Network\)](https://tools.ietf.org/html/draft-mahalingam-dutt-dcops-vxlan-02)
是一种基于IP网络\(L3\)的基础上虚拟L2网络连接的解决方案.
为多租户平台提供了虚拟网络强大的扩展能力和隔离性.
是"软件定义网络"\(Software-defined Networking, 简称SDN\)的协议之一.

相比vlan, vxlan有着以下优势：

* 使用一个24 bit的VXLAN Network Identifier \(VNI\)来区分不同的子网，这在多租户场景下提供了很强的扩展能力
* vxlan的不同主机之间的虚拟网络的通信时，通过UDP封装L2数据

通俗来讲，vxlan在多个主机原有的IP网络（可能无法直接在L2直接通信）中抽象出很多自定义的网络.

这里有一个关键的设备vtep\(VXLAN Tunnel End Point\)承担了自定义虚拟子网中不同网段的L2通信的转发.

图1. vxlan定义的逻辑网络

> 图1中使用传统虚拟化来说明vxlan的逻辑网络，在容器网络也有着相同的网络架构  
> 图中每个逻辑子网对应唯一的VNI以及虚拟子网，如：
>
> VNI=1000可能对应了171.30.0.0/16, 而VNI=1001可能对应了172.31.0.0/16

![](/assets/vxlan.png)

# Linux内核的vxlan支持

[2012年10月](https://lwn.net/Articles/518292/)，Linux内核增加了vxlan支持.  
内核的版本要求3.7+, 推荐升级到3.9+.

Linux内核支持vxlan意味着linux系统可以为主机内的虚拟网络提供直接得vxlan服务.  
当然，这需要进行一些比较复杂的网络配置，可以通过诸如Flannel的实现来自动完成.

## 实验：手动配置vxlan网络

[![asciicast](https://asciinema.org/a/bavkebqxc4wjgb2zv0t97es9y.png)](https://asciinema.org/a/bavkebqxc4wjgb2zv0t97es9y)

实验环境：

> 采用Digital Ocean上的两台CentOS 7 VPS

| Hostname | OS | Kernel | eth0 |
| :--- | :--- | :--- | :--- |
| node1 | CentOS 7 | 3.10.0 | $external-ip-of-node-1 |
| node2 | CentOS 7 | 3.10.0 | $external-ip-of-node-2 |

实验目标：在实验主机上搭建虚拟子网192.1.0.0/16, 让主机上vxlan子网内的虚拟IP直接通信

图2. 预期的网络拓扑

![](/assets/expected-network-topography-vxlan.png)

基于vxlan手动搭建Docker Overlay Network可以分为以下几步：

* 创建docker bridge: 可以通过修改默认的docker0的CIDR来达到
* 创建vxlan vteps: 通过iproute2命令来完成

### 创建docker bridge

默认的docker bridge地址范围是172.17.0.1/24(比较老的版本是172.17.42.1/24)，
而本实验中两个节点node1和node2的子网要求分别为: 192.1.78.1/24，192.1.87.1/24

修改docker daemon启动参数，增加以下参数后重启docker daemon:

```
# node1: --bip=192.1.78.1/24
# node2: --bip=192.1.87.1/24
```

这时node1和node2的容器之间还不能直接通信，
node1也不能跨主机和node2上的容器直接通信，反之node2也无法直接和node1上的容器通信.

### 创建vxlan vteps

在node1上执行以下脚本:

```
# node1

PREFIX=vxlan
IP=$external-ip-of-node-1
DESTIP=$external-ip-of-node-2
PORT=8579
VNI=1
SUBNETID=78
SUBNET=192.$VNI.0.0/16
VXSUBNET=192.$VNI.$SUBNETID.0/32
DEVNAME=$PREFIX.$VNI

ip link delete $DEVNAME
ip link add $DEVNAME type vxlan id $VNI dev eth0 local $IP dstport $PORT nolearning

echo '3' > /proc/sys/net/ipv4/neigh/$DEVNAME/app_solicit

ip address add $VXSUBNET dev $DEVNAME

ip link set $DEVNAME up

ip route delete $SUBNET dev $DEVNAME scope global
ip route add $SUBNET dev $DEVNAME scope global
```

在node2上执行以下脚本:

```
# node2

PREFIX=vxlan
IP=$external-ip-of-node-2
DESTIP=$external-ip-of-node-1
VNI=1
SUBNETID=87
PORT=8579
SUBNET=192.$VNI.0.0/16
VXSUBNET=192.$VNI.$SUBNETID.0/32
DEVNAME=$PREFIX.$VNI

ip link delete $DEVNAME
ip link add $DEVNAME type vxlan id $VNI dev eth0 local $IP dstport $PORT nolearning

echo '3' > /proc/sys/net/ipv4/neigh/$DEVNAME/app_solicit

ip -d link show

ip addr add $VXSUBNET dev $DEVNAME

ip link set $DEVNAME up

ip route delete $SUBNET dev $DEVNAME scope global
ip route add $SUBNET dev $DEVNAME scope global
```

为vtep配置forward table, 如果是跨主机的虚拟子网IP就直接转发给对应的目标主机vtep:

```
# node1

node1$ bridge fdb add $mac-of-vtep-on-node-2 dev $DEVNAME dst $DESTIP
```

```
# node2

node2$ bridge fdb add $mac-of-vtep-on-node-1 dev $DEVNAME dst $DESTIP
```

配置neighors(ARP table):

> ARP表通常不会手动更新，在vxlan的实现中多由对应的network agent根据L3 MISS来
> 动态更新; 这里手动添加ARP entry仅仅是为了测试; 另外，如果跨主机访问多个IP，
> 每个跨主机的IP就都需要配置对应的ARP entry.

```
# node1

node1$ ip neighbor add $ip-on-node-2 lladdr $mac-of-vtep-on-node-2 dev vxlan.1
```

```
# node2

node2$ ip neighbor add $ip-on-node-1 lladdr $mac-of-vtep-on-node-1 dev vxlan.1
```

### 测试Overlay Network连通性

这里通过测试2种连通性来总结本实验：

* 容器 <-> 跨主机容器直接通信
* 主机 -> 跨主机容器直接通信

先看容器与跨主机容器间直接通信的测试.

现在node1和node2上分别起一个busybox:

```
node1$ docker run -it --rm busybox sh

node1$ ip a

1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
6: eth0@if7: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue
    link/ether 02:42:c0:01:4e:02 brd ff:ff:ff:ff:ff:ff
    inet 192.1.78.2/24 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:c0ff:fe01:4e02/64 scope link
       valid_lft forever preferred_lft forever

node2$ docker run -it --rm busybox sh

node2$ ip a

1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
10: eth0@if11: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue
    link/ether 02:42:c0:01:57:02 brd ff:ff:ff:ff:ff:ff
    inet 192.1.87.2/24 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:c0ff:fe01:5702/64 scope link
       valid_lft forever preferred_lft forever
```

来享受一下容器之间的连通性：

```
node1@busybox$ ping -c1 192.1.87.2

PING 192.1.87.2 (192.1.87.2): 56 data bytes
64 bytes from 192.1.87.2: seq=0 ttl=62 time=2.002 ms
```

```
node2@busybox$ ping -c1 192.1.78.2

PING 192.1.78.2 (192.1.78.2): 56 data bytes
64 bytes from 192.1.78.2: seq=0 ttl=62 time=1.360 ms
```

然后看主机和跨主机容器之间连通性的测试.

```
node1$ ping -c1 192.1.87.2

PING 192.1.87.2 (192.1.87.2) 56(84) bytes of data.
64 bytes from 192.1.87.2: icmp_seq=1 ttl=63 time=1.49 ms
```

```
node2$ ping -c1 192.1.78.2

PING 192.1.78.2 (192.1.78.2) 56(84) bytes of data.
64 bytes from 192.1.78.2: icmp_seq=1 ttl=63 time=1.34 ms
```

![](/assets/wanmei.jpeg)

# Flannel中vxlan backend实现

弄清楚了kernel中vxlan的原理后，就不难理解Flannel的机制了：

* 使用vxlan backend时，数据是由Kernel转发的，Flannel不转发数据，仅仅动态设置ARP entry

> 这里讨论的Flannel基于v0.7.0源码

vxlan backend启动时会动态启动两个并发任务：

* 监听Kernel中L3 MISS并反序列化成Golang对象
* 根据L3 MISS和子网范围来配置合理的ARP entry

先看一下启动两个任务的源码入口：

```
// backend/vxlan/network.go
 57 func (nw *network) Run(ctx context.Context) {
 58     log.V(0).Info("Watching for L3 misses")
 59     misses := make(chan *netlink.Neigh, 100)
 60     // Unfortunately MonitorMisses does not take a cancel channel
 61     // as there's no wait to interrupt netlink socket recv
        // 这里启动一个任务来监听系统的L3 MISS，反序列化后通过channel传递给后续任务
 62     go nw.dev.MonitorMisses(misses)
 63
 64     wg := sync.WaitGroup{}
 65
 66     log.V(0).Info("Watching for new subnet leases")
 67     events := make(chan []subnet.Event)
 68     wg.Add(1)
 69     go func() {
 70         subnet.WatchLeases(ctx, nw.subnetMgr, nw.name, nw.SubnetLease, events)
 71         log.V(1).Info("WatchLeases exited")
 72         wg.Done()
 73     }()
 74
 75     defer wg.Wait()
 76
 77     select {
 78     case initialEventsBatch := <-events:
 79         for {
 80             err := nw.handleInitialSubnetEvents(initialEventsBatch)
 81             if err == nil {
 82                 break
 83             }
 84             log.Error(err, " About to retry")
 85             time.Sleep(time.Second)
 86         }
 87
 88     case <-ctx.Done():
 89         return
 90     }
 91
 92     for {
 93         select {
 94         case miss := <-misses:
                // 处理L3 MISS消息
 95             nw.handleMiss(miss)
 96
 97         case evtBatch := <-events:
 98             nw.handleSubnetEvents(evtBatch)
 99
100         case <-ctx.Done():
101             return
102         }
103     }
104 }
```

然后看一下它怎么监听L3 MISS:

```
# backend/vxlan/device.go
213 func (dev *vxlanDevice) MonitorMisses(misses chan *netlink.Neigh) {
214     nlsock, err := nl.Subscribe(syscall.NETLINK_ROUTE, syscall.RTNLGRP_NEIGH)
215     if err != nil {
216         log.Error("Failed to subscribe to netlink RTNLGRP_NEIGH messages")
217         return
218     }
219
220     for {
221         msgs, err := nlsock.Receive()
222         if err != nil {
223             log.Errorf("Failed to receive from netlink: %v ", err)
224
225             time.Sleep(1 * time.Second)
226             continue
227         }
228
229         for _, msg := range msgs {
230             dev.processNeighMsg(msg, misses)
231         }
232     }
233 }
```

然后看处理L3 MISS消息的任务实现：

```
# backend/vxlan/network.go
227 func (nw *network) handleMiss(miss *netlink.Neigh) {
228     switch {
229     case len(miss.IP) == 0 && len(miss.HardwareAddr) == 0:
230         log.V(2).Info("Ignoring nil miss")
231
232     case len(miss.HardwareAddr) == 0:
233         nw.handleL3Miss(miss)
234
235     default:
236         log.V(4).Infof("Ignoring not a miss: %v, %v", miss.HardwareAddr, miss.IP)
237     }
238 }

240 func (nw *network) handleL3Miss(miss *netlink.Neigh) {
241     route := nw.routes.findByNetwork(ip.FromIP(miss.IP))
242     if route == nil {
243         log.V(0).Infof("L3 miss but route for %v not found", miss.IP)
244         return
245     }
246
        // 其他的代码都浅显易懂，唯一值得一提的就是这里设置的neighbor的目标MAC全部都是目标地址对应vtep的MAC
247     if err := nw.dev.AddL3(neighbor{IP: ip.FromIP(miss.IP), MAC: route.vtepMAC}); err != nil {
248         log.Errorf("AddL3 failed: %v", err)
249     } else {
250         log.V(2).Infof("L3 miss: AddL3 for %s succeeded", miss.IP)
251     }
252 }

```


