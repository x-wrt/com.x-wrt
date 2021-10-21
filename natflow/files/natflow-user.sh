#!/bin/sh

list_users()
{
	cat /proc/net/nf_conntrack | grep "udp.*dst=127.255.255.255 sport=0 dport=65535" | grep -v "mark=0 " | \
	while read _ _ _ _ timeout sip _ _ _ rxp rxB _ himac _ lomac _ txp txB type _; \
	do
		himac=${himac##src=}
		himac=$(printf '%02x:' ${himac//./ })
		lomac=$(printf '%04x:' ${lomac##sport=})
		mac=$himac${lomac:0:2}:${lomac:2:2}
		type=0x$(printf '%x' ${type##mark=})
		rxp=${rxp##packets=}
		rxB=${rxB##bytes=}
		txp=${txp##packets=}
		txB=${txB##bytes=}
		echo $sip,mac=$mac,type=$type,timeout=$timeout,rx=$rxp:$rxB,tx=$txp:$txB
	done
}

case $1 in
	list|list_users)
		list_users
	;;
	*)
		echo "natflow-user list"
	;;
esac
