#!/bin/bash

CALLINGDIR="`dirname $(readlink -f $0)`"

DCACHEDIR="$CALLINGDIR/cache"

mkdir -p $DCACHEDIR

# [[ "$0" =~ "--attr=" ]] && echo "attr!"

if [[ $1 =~ --attr= ]]; then
	ATTR="${1#--attr=}"
	shift 1
fi

CMD="$1"
HASH="$2"
HASH="${HASH%/}"
HASH="${HASH##*/}"
FILE="$3"

usage() {
	if [[ $1 != "" ]]; then echo $1; fi
	echo "Usage: $0 [--attr=attrname] list|check|write|read|delete hash_value [file]"
	exit 1
}

if [[ $# == 0 ]]; then
	usage
else
	echo $HASH | awk '{exit(length($0)!="64")}' || usage "Hash length!=64!"
	if [[ "$(echo $HASH | tr -d '0-9A-Fa-f')" != "" ]]; then usage "Hash contains nonhexadecimal chars!"; fi
fi

case "$CMD" in
	"list" )
		# CASES: 
		if [[ $# == 1 ]]; then
			if [[ $ATTR == "" ]]; then
				#echo dcache.sh list
				ls -1 -d $DCACHEDIR/*
				RC=$?
			else
				#echo dcache.sh --attr=name list
				find $DCACHEDIR/ -name "${ATTR}" -exec \
					sh -c 'echo -n '{}'" [ "; cat '{}'|tr -s "\n" " " | awk "{ print(substr(\$0,1,64)) }" | tr -d "\n"; echo "]"' \;
				RC=$?
			fi
			exit $RC
		fi

		if [[ $# == 2 ]]; then
			if [[ $ATTR == "" ]]; then
				#echo dcache.sh list sha256
				echo "$(ls -s $DCACHEDIR/$HASH/.data|awk '{print $1}') $(cat $DCACHEDIR/$HASH/.data.sha256)"
				find $DCACHEDIR/$HASH/* -exec \
					sh -c 'echo -n '{}'" [ "; cat '{}'|tr -s "\n" " " | awk "{ print(substr(\$0,1,64)) }" | tr -d "\n"; echo "]"' \;
				RC=$?
			else
				#echo dcache.sh --attr=name list sha256
				ls -1 -d $DCACHEDIR/$HASH/$ATTR
				RC=$?
				cat $DCACHEDIR/$HASH/$ATTR
			fi
			exit $RC
		fi

		;;
	"check" )
		# CASES:
		if [[ $# == 2 ]]; then
			if [[ $ATTR != "" ]] ; then 
		        	# echo dcache.sh --attr=name check sha256
				test -f $DCACHEDIR/$HASH/$ATTR
				exit $?
			else
		        	# echo dcache.sh check sha256
				test -f $DCACHEDIR/$HASH/.data && test -f $DCACHEDIR/$HASH/.data.sha256
				exit $?
			fi
		fi
		usage
		;;
	"write" )
		# CASES:
		if [[ $# == 2 ]]; then
			if [[ $ATTR != "" ]]; then
				# echo dcache.sh --attr=name write sha256
				touch $DCACHEDIR/$HASH/$ATTR && \
				chmod 0200 $DCACHEDIR/$HASH/$ATTR && \
				cat > $DCACHEDIR/$HASH/$ATTR && \
				chmod 0400 $DCACHEDIR/$HASH/$ATTR
				exit $?
			else
				# echo "dcache.sh write file"
				FILE="$HASH"
				SHASUM=$(sha256sum $FILE|awk '{print $1}') || exit 1
				HASH="$SHASUM"
				mkdir -p $DCACHEDIR/$HASH/ && \
				touch $DCACHEDIR/$HASH/{.data,.data.sha256,name} && \
				chmod 0200 $DCACHEDIR/$HASH/{.data.sha256,name} && \
				chmod 0300 $DCACHEDIR/$HASH/.data && \
				cat $FILE > $DCACHEDIR/$HASH/.data && \
				echo $SHASUM > $DCACHEDIR/$HASH/.data.sha256 && \
			        echo $(basename $FILE) > $DCACHEDIR/$HASH/name && \
				chmod 0400 $DCACHEDIR/$HASH/{.data.sha256,name} && \
				chmod 0500 $DCACHEDIR/$HASH/.data && \
				echo $SHASUM
				exit $?
			fi

		elif [[ $# == 3 ]]; then
			# echo dcache.sh write sha256 file
			SHASUM=$(sha256sum $FILE|awk '{print $1}') && \
			mkdir -p $DCACHEDIR/$HASH/ && \
			touch $DCACHEDIR/$HASH/{.data,.data.sha256} && \
			chmod 0200 $DCACHEDIR/$HASH/.data.sha256 && \
			chmod 0300 $DCACHEDIR/$HASH/.data && \
			cat $FILE > $DCACHEDIR/$HASH/.data && \
			echo $SHASUM > $DCACHEDIR/$HASH/.data.sha256 && \
			chmod 0400 $DCACHEDIR/$HASH/.data.sha256 && \
			chmod 0500 $DCACHEDIR/$HASH/.data
			exit $?
		fi
		usage
		;;
	"read" )
		# CASES:
		if [[ $# == 2 ]]; then
			# echo dcache.sh --attr=name read
			cat < $DCACHEDIR/$HASH/$ATTR
			exit $?
		elif [[ $# == 3 ]]; then
			# echo dcache.sh read sha256 file
			ln -s $DCACHEDIR/$HASH/.data $FILE && \
			ln -s $DCACHEDIR/$HASH/.data.sha256 ${FILE}.sha256
			exit $?
		fi
		usage
		;;
	"delete" )
		# CASES:
		if [[ $ATTR != "" ]]; then
			# echo dcache.sh --attr=name delete sha256
			chmod 0200 $DCACHEDIR/$HASH/$ATTR && \
			rm $DCACHEDIR/$HASH/$ATTR
			exit $?
		else
			# echo dcache.sh delete sha256
			rm -r $DCACHEDIR/$HASH/
			exit $?
		fi
		usage
		;;
	*)
		usage
		;;
esac
