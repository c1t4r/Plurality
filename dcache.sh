#!/bin/bash

CALLINGDIR="`dirname $(readlink -f $0)`"

FCACHEDIR="$CALLINGDIR/cache"

mkdir -p $FCACHEDIR

[[ "$0" =~ "--attr=" ]] && echo "attr!"


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

echo $HASH | awk '{exit(length($0)!="64")}' || usage "Hash length!=64!"
if [[ "$(echo $HASH | tr -d '0-9A-Fa-f')" != "" ]]; then usage "Hash contains nonhexadecimal chars!"; fi

case "$CMD" in
	"list" )
		# CASES: 
		if [[ $# == 1 ]]; then
			if [[ $ATTR == "" ]]; then
				#echo fcache.sh list
				ls -1 -d $FCACHEDIR/*
				RC=$?
			else
				#echo fcache.sh --attr=name list
				find $FCACHEDIR/ -name "${ATTR}" -exec \
					sh -c 'echo -n '{}'" [ "; cat '{}'|tr -s "\n" " " | awk "{ print(substr(\$0,1,64)) }" | tr -d "\n"; echo "]"' \;
				RC=$?
			fi
			exit $RC
		fi

		if [[ $# == 2 ]]; then
			if [[ $ATTR == "" ]]; then
				#echo fcache.sh list sha256
				echo "$(ls -s $FCACHEDIR/$HASH/.data|awk '{print $1}') $(cat $FCACHEDIR/$HASH/.data.sha256)"
				find $FCACHEDIR/$HASH/* -exec \
					sh -c 'echo -n '{}'" [ "; cat '{}'|tr -s "\n" " " | awk "{ print(substr(\$0,1,64)) }" | tr -d "\n"; echo "]"' \;
				RC=$?
			else
				#echo fcache.sh --attr=name list sha256
				ls -1 -d $FCACHEDIR/$HASH/$ATTR
				RC=$?
				cat $FCACHEDIR/$HASH/$ATTR
			fi
			exit $RC
		fi

		;;
	"check" )
		# CASES:
		if [[ $# == 2 ]]; then
			if [[ $ATTR != "" ]] ; then 
		        	# echo fcache.sh --attr=name check sha256
				test -f $FCACHEDIR/$HASH/$ATTR
				exit $?
			else
		        	# echo fcache.sh check sha256
				test -f $FCACHEDIR/$HASH/.data && test -f $FCACHEDIR/$HASH/.data.sha256
				exit $?
			fi
		fi
		usage
		;;
	"write" )
		# CASES:
		if [[ $# == 2 ]]; then
			if [[ $ATTR != "" ]]; then
				# echo fcache.sh --attr=name write sha256
				touch $FCACHEDIR/$HASH/$ATTR && \
				chmod 0200 $FCACHEDIR/$HASH/$ATTR && \
				cat > $FCACHEDIR/$HASH/$ATTR && \
				chmod 0400 $FCACHEDIR/$HASH/$ATTR
				exit $?
			else
				# echo "fcache.sh write file"
				FILE="$HASH"
				SHASUM=$(sha256sum $FILE|awk '{print $1}') || exit 1
				HASH="$SHASUM"
				mkdir -p $FCACHEDIR/$HASH/ && \
				touch $FCACHEDIR/$HASH/{.data,.data.sha256,name} && \
				chmod 0200 $FCACHEDIR/$HASH/{.data.sha256,name} && \
				chmod 0300 $FCACHEDIR/$HASH/.data && \
				cat $FILE > $FCACHEDIR/$HASH/.data && \
				echo $SHASUM > $FCACHEDIR/$HASH/.data.sha256 && \
			        echo $(basename $FILE) > $FCACHEDIR/$HASH/name && \
				chmod 0400 $FCACHEDIR/$HASH/{.data.sha256,name} && \
				chmod 0500 $FCACHEDIR/$HASH/.data && \
				echo $SHASUM
				exit $?
			fi

		elif [[ $# == 3 ]]; then
			# echo fcache.sh write sha256 file
			SHASUM=$(sha256sum $FILE|awk '{print $1}') && \
			mkdir -p $FCACHEDIR/$HASH/ && \
			touch $FCACHEDIR/$HASH/{.data,.data.sha256} && \
			chmod 0200 $FCACHEDIR/$HASH/.data.sha256 && \
			chmod 0300 $FCACHEDIR/$HASH/.data && \
			cat $FILE > $FCACHEDIR/$HASH/.data && \
			echo $SHASUM > $FCACHEDIR/$HASH/.data.sha256 && \
			chmod 0400 $FCACHEDIR/$HASH/.data.sha256 && \
			chmod 0500 $FCACHEDIR/$HASH/.data
			exit $?
		fi
		usage
		;;
	"read" )
		# CASES:
		if [[ $# == 2 ]]; then
			echo fcache.sh --attr=name read
			cat < $FCACHEDIR/$HASH/$ATTR
			exit $?
		elif [[ $# == 3 ]]; then
			echo fcache.sh read sha256 file
			ln -s $FCACHEDIR/$HASH/.data $FILE && \
			ln -s $FCACHEDIR/$HASH/.data.sha256 ${FILE}.sha256
			exit $?
		fi
		usage
		;;
	"delete" )
		# CASES:
		if [[ $ATTR != "" ]]; then
			# echo fcache.sh --attr=name delete sha256
			chmod 0200 $FCACHEDIR/$HASH/$ATTR && \
			rm $FCACHEDIR/$HASH/$ATTR
			exit $?
		else
			# echo fcache.sh delete sha256
			rm -r $FCACHEDIR/$HASH/
			exit $?
		fi
		usage
		;;
	*)
		usage
		;;
esac
