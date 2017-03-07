#!/bin/sh
##################################################################
# Simple script to profile the network inside a kubernetes cluster
# Goto man page of qperf for more details:
#        https://linux.die.net/man/1/qperf
##################################################################

# Create the qperf server rc and service
kubectl create -f https://raw.githubusercontent.com/yangyuqian/k8s-the-hard-way/master/assets/qperf-server.yaml

# Profile the service
echo "Profileing TCP and UDP on Service ..."
kubectl run qperf-client -it --rm --image="arjanschaaf/centos-qperf" -- -v qperf-server -lp 4000 -ip 4001  tcp_bw tcp_lat udp_bw udp_lat conf
echo "... Done"

# Profile the pod
echo "Profiling TCP and UDP on Pod ..."
podip=`kubectl get pod --selector="k8s-app=qperf-server" -o jsonpath='{ .items[0].status.podIP }'`
kubectl run qperf-client -it --rm --image="arjanschaaf/centos-qperf" -- -v $podip -lp 4000 -ip 4001  tcp_bw tcp_lat udp_bw udp_lat conf
echo "... Done"

# Cleanup the testing rc and service
kubectl delete -f https://raw.githubusercontent.com/yangyuqian/k8s-the-hard-way/master/assets/qperf-server.yaml
