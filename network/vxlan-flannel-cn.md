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

本文将介绍对平台和协议耦合最低的两个方案之一： `vxlan`的原理及实现，
包含以下内容：

* vxlan简介
* Linux内核的vxlan支持
* Flannel中vxlan backend实现原理

# vxlan简介

[vxlan(Virtual eXtensible Local Area Network)](https://tools.ietf.org/html/draft-mahalingam-dutt-dcops-vxlan-02) 是一种基于IP网络(L3)的基础上虚拟
L2网络连接的解决方案. vxlan为多租户平台提供了虚拟网络强大的扩展能力和隔离性.

相比vlan, vxlan有着以下优势：

* 使用一个24 bit的VXLAN Network Identifier (VNI)来区分不同的子网，这在多租户场景下提供了很强的扩展能力
* vxlan的不同主机之间的虚拟网络的通信时，通过UDP封装L2数据

通俗来讲，vxlan在多个主机原有的IP网络（可能无法直接在L2直接通信）中抽象出很多自定义的网络.

这里有一个关键的设备vtep(VXLAN Tunnel End Point)承担了自定义虚拟子网中不同网段的L2通信的转发.

Figure 1. vxlan网络模型



# Linux内核的vxlan支持

# Flannel中vxlan backend实现原理


