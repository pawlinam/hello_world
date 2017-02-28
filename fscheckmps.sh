#!/bin/sh
###########################################################################
# Copyright (C) 2016 Amdocs. All rights reserved.                         #
#                                                                         #
# fscheckmps                                                              #
#                                                                         #
# Author: Michal Pawlina (michal.pawlina@amdocs.com)                      #
#                                                                         #
# Version 1.2                                                             #
#                                                                         #
# Changes:		                                                  #
#  v1.0 - Initial release                                                 #
#  v1.1 - Adding sendmail support for notification mails                  #
#  v1.2 - Added GitHub repo                                               #
#                                                                         #
###########################################################################

function printUse {
  echo " "
  echo "Usage: $0 filesystem threshold sleeptime"
  echo "  filesystem - share to be checked for size"
  echo "  threshold - a limit above which CAP kill signal is sent (%)"
  echo "  sleeptime - number of seconds between checks"
  echo " "
}

function mecho
{
	data_log=$(date '+%Y-%m-%d %H:%M:%S')
	echo "${data_log} $*"	
} 

function stopCAP
{
	cap_count=`ps -ef | grep /CAP | grep -v grep | grep $unixuser | wc -l`;
	mecho "No of CAP running (user $unixuser): $cap_count"
	if [ $cap_count -gt 0 ]; then
		ps -ef | grep /CAP | grep -v grep | grep $unixuser | awk '{print $2}' | while read pid; do 
			mecho "Sending kill signal for pid $pid" 
			kill $pid; 
		done;
		mecho "Kill signals sent...wait for CAP to stop"
		lockAndNotify
	fi;
}

function sendNotificationMail
{
	mecho "Mail sent to: "
}

function lockAndNotify
{
 	if [ -f ${sendlock} ]; then
		mecho "Notification mail sent already"
	else
		mecho "Going to send notification mail"
		echo $fscheckpid > ${sendlock}
		chmod 777 ${sendlock}
	 	# notify by mail	
		sendNotificationMail
 	fi		
}


function unlockNotification
{
	if [ -f ${sendlock} ]; then
		rm -rf ${sendlock}
	fi
}

function cleanExit
{
        mecho "Signal SIGHUP SIGINT SIGTERM received, exiting"
        unlockNotification
        exit
}


if [ $# -ne 3 ];
then
        printUse
        exit 0
fi 

trap cleanExit SIGHUP SIGINT SIGTERM 

fscheck=$1
limit=$2
unixuser=`whoami`
sleeptime=$3
sendlock=.lock.fscheck
fscheckpid=$$

while true; do

curr=`bdf | grep $fscheck | grep % | awk '{ print $4}' | sed 's/%//g'`;
if [[ -z $curr ]]; then
	mecho "Cannot check file system $fscheck";
	exit 1;
fi;
 
mecho "Allocated space on ${fscheck}: ${curr}%"
mecho "Threshold for ${fscheck}: ${limit}%"


if [ $curr -gt $limit ]; then
	mecho "Filesystem ${fscheck} free space over threshold, checking if CAP are running";
	stopCAP;
else
	mecho "Filesystem ${fscheck} free space under control"
 	unlockNotification;	
fi;

sleep $sleeptime

done;

