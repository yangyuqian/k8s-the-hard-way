vxlan在Flannel中的Overlay网络的实现
-------------

Flannel(v0.7+)支持接入不同的`backend`来搭建Overlay网络，如:

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
* Flannel中vxlan backend实现原理

# vxlan简介

[vxlan(Virtual eXtensible Local Area Network)](https://tools.ietf.org/html/draft-mahalingam-dutt-dcops-vxlan-02)
是一种基于IP网络(L3)的基础上虚拟L2网络连接的解决方案.
为多租户平台提供了虚拟网络强大的扩展能力和隔离性.
是"软件定义网络"(Software-defined Networking, 简称SDN)的协议之一.

相比vlan, vxlan有着以下优势：

* 使用一个24 bit的VXLAN Network Identifier (VNI)来区分不同的子网，这在多租户场景下提供了很强的扩展能力
* vxlan的不同主机之间的虚拟网络的通信时，通过UDP封装L2数据

通俗来讲，vxlan在多个主机原有的IP网络（可能无法直接在L2直接通信）中抽象出很多自定义的网络.

这里有一个关键的设备vtep(VXLAN Tunnel End Point)承担了自定义虚拟子网中不同网段的L2通信的转发.

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

实验环境：

> 采用Digital Ocean上的两台CentOS 7 VPS

|主机名|OS|Kernel|eth0|
|------|--|------|----|
|node1|CentOS 7|Linux 3.10.0-514.6.1.el7.x86_64|TODO|
|node2|CentOS 7|Linux 3.10.0-514.6.1.el7.x86_64|TODO|

# Flannel中vxlan backend实现原理


