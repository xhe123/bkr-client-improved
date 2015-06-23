#!/bin/bash
#author: jiyin@redhat.com

export LANG=C
infoecho() { echo -e "\n${P:-DO ==>}" "\E[1;34m" "$@" "\E[0m"; }
errecho() { echo -e "\n${P:-DO ==>}" "\E[31m" "$@" "\E[0m"; }
KRB_CONF=/etc/krb5.conf
krbServ=$1
#realm=${2:-RHQE.COM}
realm=RHQE.COM
pkgs=krb5-workstation

krbConfTemp="[logging]%N default = FILE:/var/log/krb5libs.log%N kdc = FILE:/var/log/krb5kdc.log%N admin_server = FILE:/var/log/kadmind.log%N%N[libdefaults]%N dns_lookup_realm = false%N ticket_lifetime = 24h%N renew_lifetime = 7d%N forwardable = true%N rdns = false%N default_realm = EXAMPLE.COM%N%N[realms]%N EXAMPLE.COM = {%N  kdc = kerberos.example.com%N  admin_server = kerberos.example.com%N }%N%N[domain_realm]%N .example.com = EXAMPLE.COM%N example.com = EXAMPLE.COM%N"

[ $# = 0 ] && {
	echo "usage: $0  <krb5 server address>"
	exit 1
}
[ -z "$krbServ" ] && {
	echo "{WARN} something is wrong! can not get the krb server addr."
	exit 1
}
ping -c 4 $krbServ || {
	echo "{WARN} can not cennect krb server '$krbServ'."
	exit 1
}
rpm -q telnet || yum -y install telnet
echo -e "\[" | telnet $krbServ 88 2>&1 | egrep 'Escape character is' || {
	echo "{WARN} krb port $krbServ:88 can not connect. please check the firewall of both point"
	exit 1
}

if test "$HOSTNAME" != "$krbServ"; then
	infoecho "clean old config and data ..."
	kdestroy -A
	\rm -f /etc/krb5.keytab
	\rm -f /tmp/krb5cc*  /var/tmp/krb5kdc_rcache  /var/tmp/rc_kadmin_0
	echo "$krbConfTemp"|sed 's/%N/\n/g' >$KRB_CONF
else
	grep -q "$realm" "$KRB_CONF" && infoecho "$KRB_CONF has configed ..."
fi

infoecho "make sure package $pkgs install ..."
rpm -q $pkgs || yum -y install $pkgs
#===============================================================================
infoecho "close the firewall ..."
service iptables stop
which systemctl &>/dev/null && systemctl stop firewalld

infoecho "configure '$KRB_CONF', edit the realm name ..."
sed -r -i -e 's;^#+;;' -e "/EXAMPLE.COM/{s//$realm/g}" -e "/kerberos.example.com/{s//$krbServ/g}"   $KRB_CONF
sed -r -i -e "/ (\.)?example.com/{s// \1${krbServ#*.}/g}"   $KRB_CONF

infoecho "test connect to KDC with kadmin ..."
kadmin -p root/admin -w redhat -q "listprincs"

infoecho "create nfs princs and ext keytab ..."
host=$HOSTNAME
nfsprinc=nfs/${host}
kadmin -p root/admin -w redhat -q "addprinc -randkey $nfsprinc"
kadmin -p root/admin -w redhat -q "ktadd -k /etc/krb5.keytab $nfsprinc"

infoecho "create root@ and krbAccount@ princs and ext keytab ..."
klist -e -k -t /etc/krb5.keytab|grep -q 'root@' ||
    kadmin -p root/admin -w redhat -q "ktadd -k /etc/krb5.keytab root"

infoecho "test the /etc/krb5.keytab ..."
klist -e -k -t /etc/krb5.keytab

infoecho "fetch tickit: kinit -k  ..."
kinit -k $nfsprinc &&
	kinit -k root

