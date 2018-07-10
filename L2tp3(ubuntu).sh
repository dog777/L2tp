#!/bin/bash

if [ $(id -u) != "0" ]; then
    printf "Error: You must be root to run this tool!\n"
    exit 1
fi
clear
printf "
####################################################
#                                                  #
# This is a Shell-Based tool of l2tp installation  #
# Version: 2.0（ubuntu)                            #
# Author: 23sec                                    #
#                                                  #
####################################################
"
vpsip=`127.0.0.1`

iprange="10.1.1"
echo "Please input IP-Range:"
read -p "(Default Range: 10.1.1):" iprange
if [ "$iprange" = "" ]; then
	iprange="10.1.1"
fi

mypsk="psk.com"
echo "Please input PSK:"
read -p "(Default PSK: psk.com):" mypsk
if [ "$mypsk" = "" ]; then
	mypsk="psk.com"
fi

user="test"
echo "Please input Username:"
read -p "(Default Username: test):" user
if [ "$user" = "" ]; then
    user="test"
fi

pass="test123"
echo "Please input Password:"
read -p "(Default Password: test123):" pass
if [ "$pass" = "" ]; then
    pass="test123"
fi

clear
get_char()
{
SAVEDSTTY=`stty -g`
stty -echo
stty cbreak
dd if=/dev/tty bs=1 count=1 2> /dev/null
stty -raw
stty echo
stty $SAVEDSTTY
}
echo ""
echo "ServerIP:"
echo "$vpsip"
echo ""
echo "Server Local IP:"
echo "$iprange.1"
echo ""
echo "Client Remote IP Range:"
echo "$iprange.2-254"
echo ""
echo "PSK:"
echo "$mypsk"
echo ""
echo "Username:"
echo "$user"
echo ""
echo "Password:"
echo "$pass"
echo ""
echo "Press any key to start...or Press Ctrl+c to cancel"
char=`get_char`
clear
mknod /dev/random c 1 9
sudo apt-get upgrade -y
sudo apt-get update -y
sudo apt-get install -y ppp iptables make gcc  kernel-devel kernel-header gmp  gawk gmp-devel xmlto bison flex xmlto libpcap libpcap-devel lsof vim-enhanced man
mkdir /ztmp
mkdir /ztmp/l2tp
cd /ztmp/l2tp
wget https://download.openswan.org/openswan//openswan-2.6.50.tar.gz
tar zxvf openswan-2.6.50.tar.gz
cd openswan-2.6.50
make programs install
rm -rf /etc/ipsec.conf
touch /etc/ipsec.conf
cat >>/etc/ipsec.conf<<EOF
config setup
    nat_traversal=yes
    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12
    oe=off
    protostack=netkey
conn L2TP-PSK-NAT
    rightsubnet=vhost:%priv
    also=L2TP-PSK-noNAT
conn L2TP-PSK-noNAT
    authby=secret
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=$vpsip
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
EOF
cat >>/etc/ipsec.secrets<<EOF
$vpsip %any: PSK "$mypsk"
EOF
cp /etc/sysctl.conf /etc/sysctl.conf.bak
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
sed -i 's/net.ipv4.conf.default.rp_filter = 1/net.ipv4.conf.default.rp_filter = 0/g' /etc/sysctl.conf
echo net.ipv4.conf.all.send_redirects = 0 >> /etc/sysctl.conf
echo net.ipv4.conf.default.send_redirects = 0 >> /etc/sysctl.conf
echo net.ipv4.conf.all.log_martians = 0 >> /etc/sysctl.conf
echo net.ipv4.conf.default.log_martians = 0 >> /etc/sysctl.conf
echo net.ipv4.conf.all.accept_redirects = 0 >> /etc/sysctl.conf
echo net.ipv4.conf.default.accept_redirects = 0 >> /etc/sysctl.conf
echo net.ipv4.icmp_ignore_bogus_error_responses = 1 >> /etc/sysctl.conf
sysctl -p
iptables --table nat --append POSTROUTING --jump MASQUERADE
for each in /proc/sys/net/ipv4/conf/*
do
echo 0 > $each/accept_redirects
echo 0 > $each/send_redirects
done
/etc/init.d/ipsec restart
ipsec verify
cd /ztmp/l2tp
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/Packages/x/xl2tpd-1.3.8-1.el6.x86_64.rpm
yum install xl2tpd-1.3.8-1.el6.x86_64.rpm -y
cp handlers/l2tp-control /usr/local/sbin/
mkdir /var/run/xl2tpd/
ln -s /usr/local/sbin/l2tp-control /var/run/xl2tpd/l2tp-control
cd /ztmp/l2tp
wget https://download.openswan.org/xl2tpd/xl2tpd-1.3.0.tar.gz
tar zxvf xl2tpd-1.3.0.tar.gz
cd xl2tpd-1.3.0
make install
mkdir /etc/xl2tpd
rm -rf /etc/xl2tpd/xl2tpd.conf
touch /etc/xl2tpd/xl2tpd.conf
cat >>/etc/xl2tpd/xl2tpd.conf<<EOF
[global]
ipsec saref = yes
[lns default]
ip range = $iprange.2-254
local ip = $iprange.1
refuse chap = yes
refuse pap = yes
require authentication = yes
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF
rm -rf /etc/ppp/options.xl2tpd
touch /etc/ppp/options.xl2tpd
cat >>/etc/ppp/options.xl2tpd<<EOF
require-mschap-v2
ms-dns 8.8.8.8
ms-dns 8.8.4.4
asyncmap 0
auth
crtscts
lock
hide-password
modem
debug
name l2tpd
proxyarp
lcp-echo-interval 30
lcp-echo-failure 4
EOF
cat >>/etc/ppp/chap-secrets<<EOF
$user l2tpd $pass *
EOF
touch /usr/bin/zl2tpset
echo "#/bin/bash" >>/usr/bin/zl2tpset
echo "for each in /proc/sys/net/ipv4/conf/*" >>/usr/bin/zl2tpset
echo "do" >>/usr/bin/zl2tpset
echo "echo 0 > \$each/accept_redirects" >>/usr/bin/zl2tpset
echo "echo 0 > \$each/send_redirects" >>/usr/bin/zl2tpset
echo "done" >>/usr/bin/zl2tpset
chmod +x /usr/bin/zl2tpset
iptables --table nat --append POSTROUTING --jump MASQUERADE
zl2tpset
xl2tpd
cat >>/etc/rc.local<<EOF
iptables --table nat --append POSTROUTING --jump MASQUERADE
/etc/init.d/ipsec restart
/usr/bin/zl2tpset
/usr/local/sbin/xl2tpd
EOF
clear
ipsec verify
iptables -A INPUT -m policy --dir in --pol ipsec -j ACCEPT
iptables -A FORWARD -m policy --dir in --pol ipsec -j ACCEPT
iptables -t nat -A POSTROUTING -m policy --dir out --pol none -j MASQUERADE
iptables -A FORWARD -i ppp+ -p all -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -m policy --dir in --pol ipsec -p udp --dport 1701 -j ACCEPT
iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o eth0 -j MASQUERADE
service iptables save
service iptables restart


printf "
####################################################
#                                                  #
# This is a Shell-Based tool of l2tp installation  #
# Version: 2.0（ubuntu）                            #
# Author: 23sec                                    #
#                                                  #
####################################################
if there are no [FAILED] above, then you can
connect to your L2TP VPN Server with the default
user/pass below:

ServerIP:$vpsip
username:$user
password:$pass
PSK:$mypsk

"

