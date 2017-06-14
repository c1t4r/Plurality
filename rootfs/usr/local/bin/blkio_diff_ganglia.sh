#!/bin/bash
nohup /usr/local/bin/blkio_diff_ganglia.pl 300 >/dev/null 2>&1 & 
disown;
#sleep 1;
#ps aux |grep bl[k]i |grep -v sh
