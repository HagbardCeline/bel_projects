#!/bin/sh
#...
. /etc/functions

echo $NAME
log 'copying software, tools and startup script to ramdisk'
cp -a /opt/$NAME/$ARCH/usr/bin/* /usr/bin/

log 'copying firmware to ramdisk'
cp -a /opt/$NAME/firmware/* /

log 'starting the gateway'
wrmilgw-startSIS.sh | logger -t wrmilgw-startSIS -sp local0.info
