#!/system/bin/sh
#
# Copyright (c) 2023, Motorola LLC  All rights reserved.
#

scriptname=${0##*/}

debug()
{
	echo "$*"
}

notice()
{
	echo "$*"
	echo "$scriptname: $*" > /dev/kmsg
}

allow_to_run()
{
	secure_hw=$(getprop ro.boot.secure_hardware)
	build_type=$(getprop ro.build.type)
	cid=$(getprop ro.boot.cid)

	if [ x"$secure_hw" == x"1" ] && [ x"$build_type" == x"user" ] && [ x"$cid" != x"0x0" ] && [ x"$cid" != x"0x0000" ]; then
		apdp_state=$(getprop ro.boot.device_apdp_state)
		aplogd_state=$(getprop ro.boot.force_aplogd_enable)
		if [ "$apdp_state" == "1" ] || [ "$aplogd_state" == "1" ]; then
			notice "secure_hw=$secure_hw build_type=$build_type cid=$cid apdp_state=$apdp_state aplogd_state=$aplogd_state"
			return
		fi
		exit 0
	fi
}

LOGCAT_LOGFILE_PREFIX_ROOT="/mnt/product/logks/logcat"
LOGCAT_LOGFILE_PREFIX_ROOT_TAIL=".log"
LOGCAT_LOGFILE_PREFIX="$LOGCAT_LOGFILE_PREFIX_ROOT$LOGCAT_LOGFILE_PREFIX_ROOT_TAIL"
POSTFIX=""

# mv files logcat.1.log.*.txt to logcat.2.log.*.txt
mv_one_batch_files()
{
	basefile=$1
	prev=$2
	target=$3

	echo mv_one_batch_files: $1 $2 $3
	file_list_count=`ls $1* | wc -w`
	#echo "middle file count = [$file_list_count]"
	if [ $file_list_count -ne 0 ]; then
		#echo "middle $basefile exist!"
		file_list=`ls $1*`
		for f in $file_list ; do
			file_target=${f/$prev.log/$target.log}
			echo middle mv $f $file_target
			mv $f $file_target
		done
	fi
}

# mv files logcat.log.*.txt to logcat.1.log.*.txt
mv_first_batch_files()
{
	basefile=$1

	#echo $1 $2 $LAST_FILE
	file_list_count=`ls $1* | wc -w`
	#echo "file count = [$file_list_count]"
	if [ $file_list_count -ne 0 ]; then
		#echo "$basefile exist!"
		file_list=`ls $1*`
		for f in $file_list ; do
			file_target=${f/.log/.1.log}
			#echo mv $f $file_target
			mv $f $file_target
		done
	fi
}

# mv files logcat.1.log.* to logcat.2.log.*
mv_files()
{
	if [ -z "$1" ]; then
	  echo "No file name!"
	  return
	fi
	if [ -z "$2" ]; then
	  LAST_FILE=3
	else
	  LAST_FILE=$2
	fi

	echo $1 $2 $LAST_FILE
	i=$LAST_FILE
	while [ $i -gt 0 ]; do
	  prev=$(($i-1))
	  echo "$LOGCAT_LOGFILE_PREFIX_ROOT.$prev$LOGCAT_LOGFILE_PREFIX_ROOT_TAIL exist?"
	  if [ -e "$LOGCAT_LOGFILE_PREFIX_ROOT.$prev$LOGCAT_LOGFILE_PREFIX_ROOT_TAIL" ]; then
	    echo middle mv $LOGCAT_LOGFILE_PREFIX_ROOT.$prev$LOGCAT_LOGFILE_PREFIX_ROOT_TAIL $LOGCAT_LOGFILE_PREFIX_ROOT.$i$LOGCAT_LOGFILE_PREFIX_ROOT_TAIL
	    mv_one_batch_files $LOGCAT_LOGFILE_PREFIX_ROOT.$prev$LOGCAT_LOGFILE_PREFIX_ROOT_TAIL $prev $i
	  fi
	  i=$(($i-1))
	done

	if [ -e $1$POSTFIX ]; then
	  echo mv_first_batch_files $1 $1.1
	  mv_first_batch_files $1 1
	fi
}

allow_to_run

while [ ! -e "/mnt/product/logks/lost+found" ]; do
	sleep 1
	notice "logks partition is not mounted, wait to try"
done

if [ -e $LOGCAT_LOGFILE_PREFIX$POSTFIX ]; then
	mv_files $LOGCAT_LOGFILE_PREFIX 1
fi

/system/bin/logcat -b main,system,crash -f $LOGCAT_LOGFILE_PREFIX$POSTFIX -r 5120 -n 3
