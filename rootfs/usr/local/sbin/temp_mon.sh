#!/bin/bash
#
# node temperature monitor for NEC Express5800/E120f-M
# warn if WARN is reached by syslog,
# message and power off in case of ALARM
#

WARN=38
ALARM=40
DELAY=30
# delay is the delay before ipmi power off

# check if module is loaded, load it if not loaded
if [ ! -c /dev/ipmi0 ]
then
	/usr/sbin/modprobe ipmi_devintf
fi

# check if this is running on a greengem
if /usr/sbin/dmidecode -t system | grep Express5800/E120f-M >/dev/null 2>/dev/null
then
	:
	# this is a GREENGEM
else
	exit
fi


# get value 
set -- $(/usr/bin/ipmitool sensor reading "FntPnl Amb Temp" 2>/dev/null)
# FIXME: output has to look like "FntPnl Amb Temp  | 27" otherwise adjust the next line
TEMP="${5:--99}"

# error exit in case of strange values
if [ "$TEMP" -ge 100 -o "$TEMP" -le 1 ]
then
        /usr/bin/logger -p daemon.warn -t temp_mon "strange front inlet temperature on $HOSTNAME $TEMP"
	exit
fi

# WARN
if [ "$TEMP" -ge "$WARN" ]
then
	/usr/bin/logger -p daemon.warn -t temp_mon "front inlet temperature on $HOSTNAME $TEMP > $WARN"
fi

# ALARM and power off
if [ "$TEMP" -ge "$ALARM" ]
then
	/usr/bin/logger -p daemon.crit -t temp_mon "front inlet temperature on $HOSTNAME $TEMP > $ALARM, switching off the node"
	## SWITCH OFF HERE, we do it nice and rough at the same time, but in parallel, to give lustre and NFS a chance
        (sleep $DELAY; ipmitool chassis power off) &
        ## be nice and umount lustre
        /usr/sbin/service lxfs_client stop 
        ## be less nice and poweroff
        /usr/sbin/poweroff
fi

