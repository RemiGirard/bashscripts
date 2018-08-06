#!/bin/bash
date=`date +%F"_"%H:%M:%S`
IFS="$(printf '\n\t')"

#set variables
folderIN="/volumeDestination/"
folderOUT="root@IP.AD.RE.SS:/volumeDestination/"
folderLog="/folderLog/"
logscript="$folderLog/rsyncWithVerification.log"
listOfFiles="$folderLog/listOfFiles.temp"

#create log folder if not exist
mkdir -p $folderLog

#function writes the date and two parameters sent to the function then add it to the main log file
logger () {
    echo "`date +%F"_"%H:%M:%S` $1 $2" | tee -a $logscript
}

logger INFO "###############################"
logger INFO "Welcome to rsyncWithVerification"
logger INFO "Version 2.0 - Remi Girard"
logger INFO "###############################"

#show source and destination of the copy, and log files location
logger INFO "INPUT: $folderIN"
logger INFO "OUPUT: $folderOUT"
logger INFO "Log folder: $folderLog"
logger INFO "Main log: $logscript"

logger INFO "rsync copy started"

# process rsync copy from $folderIN to $folderOUT and save files transfered list
listOfTransferedFile="$folderLog/INtoOUTtransfered_$date.log"
logger INFO "rsync logs: $listOfTransferedFile"
rsync -av -e "ssh" $folderIN $folderOUT > $listOfTransferedFile

# catch rsync errors
if [ "$?" -eq "0" ]
    then
    logger INFO "rsync copy ended with success"
    else
    logger ERROR "Error while running rsync with code: $?"
    logger ERROR "Read rsync manual for more information: man rsync"
    logger ERROR "Not transfered or partial transfered"
fi

logger INFO "rsync verification started"
# read rsync copy log to extract the list of files transferred to a text file $listOfFiles
cat $listOfTransferedFile | sed 1d | grep -v '/$' | head -n -3 > $listOfFiles

# process rsync verification using the list of files transferred from $folderINsimple to $folderOUT
rsyncVerificationLog=$folderLog/INtoOUTverified_$date.log
logger INFO "rsync verification logs: $rsyncVerificationLog"
rsync -avcn -e "ssh" --files-from $listOfFiles $folderINsimple $folderOUT > $rsyncVerificationLog

# catch rsync errors
if [ "$?" -eq "0" ]
then
    #read the rsync verification log to extract list of files with error, which must be usually empty
    listOfFilesWithErrors=`cat $rsyncVerificationLog | sed 1d | head -n -3`
    if [ -z "$listOfFilesWithErrors" ]
    then
        logger INFO "rsync verification ended with success"
    else
        logger ERROR "some files have differences"
        logger ERROR "Check $rsyncVerificationLog for list"
    fi
else
    logger ERROR "Error while running rsync with code: $?"
    logger ERROR "Read rsync manual for more information: man rsync"
    logger ERROR "Not verified or partially verified"
fi
