#!/bin/bash
dhcp\_ip=192.168.31.248
##############
# Flush all
for i in INPUT OUTPUT FORWARD; do
iptables -F "${i}"
iptables -P "${i}" ACCEPT
done
iptables -t nat -F PREROUTING
iptables -t nat -F POSTROUTING
for i in LAN DMZ WEB LOGGING; do
iptables -F "${i}"
iptables -X "${i}"
done
#############
# Rules
###########################
# 1: politique par défaut #
###########################
# Politique DROP pour les autres chaînes
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP
#########################
# 2: Interface loopback #
#########################
# Autoriser le trafic loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
#################
# 3: LAN et WEB #
#################
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o enp0s3 -j SNAT --to-source $dhcp\_ip
iptables -A FORWARD -s 10.0.0.0/24 -o enp0s3 -p icmp -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/24 -o enp0s3 -p tcp -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/24 -o enp0s3 -p udp -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/24 -p udp --dport 53 -d 208.67.222.123 -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/24 -p tcp --dport 53 -d 208.67.222.123 -j ACCEPT
###################
# 4: LAN vers DMZ #
###################
<<COMMENTED\_ZONE
### 4.1 : sans contrack
# autoriser le ping dans les deux sens
iptables -A INPUT -s 10.0.0.0/24 -d 172.16.0.0/30 -p icmp -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/24 -d 172.16.0.0/30 -p icmp -j ACCEPT
iptables -A OUTPUT -s 10.0.0.0/24 -d 172.16.0.0/30 -p icmp -j ACCEPT
iptables -A INPUT -s 172.16.0.0/30 -d 10.0.0.0/24 -p icmp -j ACCEPT
iptables -A FORWARD -s 172.16.0.0/30 -d 10.0.0.0/24 -p icmp -j ACCEPT
iptables -A OUTPUT -s 172.16.0.0/30 -d 10.0.0.0/24 -p icmp -j ACCEPT
# autoriser les ports 80,20 et 21 en tcp/udp
# Je n'ai pas réussi sans contrack
COMMENTED\_ZONE
### 4.2 : avec contrack
iptables -A FORWARD -s 10.0.0.0/24 -d 172.16.0.0/30 -p icmp -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/24 -d 172.16.0.0/30 -p udp --match multiport --dport 80,20,21 -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/24 -d 172.16.0.0/30 -p tcp --match multiport --dport 80,20,21 -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
###################
# 5: WEB vers DMZ #
###################
iptables -t nat -A PREROUTING -i enp0s3 -p tcp --match multiport --dports 80,20,21 -j DNAT --to-destinatiptables -A FORWARD -i enp0s3 -o enp0s8 -p tcp --match multiport --dports 80,20,21 -j ACCEPT
# partie SSH
iptables -t nat -A PREROUTING -d $dhcp\_ip -p tcp --dport 61337 -j DNAT --to-destination 172.16.0.2:22
iptables -A FORWARD -i enp0s3 -o enp0s8 -p tcp --dport 22 -j ACCEPT
########################
# 6: ANY vers pare-feu #
########################
iptables -A INPUT -p icmp -j ACCEPT
##############
# 7: Logging #
##############
# Rejeter les paquets non autorisés
iptables -A INPUT -j REJECT --reject-with icmp-port-unreachable
iptables -A FORWARD -j REJECT --reject-with icmp-port-unreachable
iptables -N LOGGING
iptables -A INPUT -j LOGGING
iptables -A OUTPUT -j LOGGING
iptables -A LOGGING -j LOG --log-prefix "ipt rejected: " --log-level 4
iptables -A LOGGING -j REJECT
