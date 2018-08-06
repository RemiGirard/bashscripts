#!/bin/bash

# AutoBackupNewDrives.sh

# detect new local volumes mounted
# transfer the new volumes to destinations
# then compare with checksum volume source and destination

# install brew
# brew install xxhash
# brew install pv

# files must don't have \ character

echo "start AutoBackupNewDrives.sh"
IFS="$(printf '\n\t')"

# parameters
watchFolder="/Volumes"
ignoreList=`ls $watchFolder`
logs=~/LOG
logscript=$logs/logscriptAutoBackupNewDrives.log
loopDuration=0.5
export PATH=/usr/local/bin:$PATH

# process vars
declare -a destinationArray=()
declare -a ignoreArray=()
logcount=0
updateThisLog=false
startedDetectingVolumes=false
points=""

# create log folder and declare log function
mkdir -p $logs
logger () {
    echo "`date +%F"_"%H:%M:%S` $1 $2" | tee -a $logscript
    # Does this line will be refreshed?
    updateThisLog=false
}
logJob (){
    echo "`date +%F"_"%H:%M:%S` $2 $3" >> $1
}



logger INFO "###################################################"
logger INFO "Welcome to AutoBackupNewDrives"
logger INFO "Version 1.0 - TSF - Remi Girard"
logger INFO "###################################################"

# send destinationList to destinationArray and display the destinations
while read item
do
    logger INFO "Destination : $item"
    destinationArray=("${destinationArray[@]}" "$item")
done < "${1:-/dev/stdin}"

# initial ignore list
# send ignoreList to ignoreArray and display the ignored volumes
for item in $ignoreList
do
    logger INFO "Ignored volume : $item"
    ignoreArray=("${ignoreArray[@]}" "$item")
done


# clear the last line in Terminal
clearLastLine () {
        tput cuu 1 && tput el
}

# take two parameters: $1 volume source, $2 destination
# transfer source in destination folder
# verify the backup with rsync checksum
transferRsync () {
    destinationFolder="$1_`date +%F"_"%H:%M:%S`"
    sourceTransfer=$watchFolder/$1/
    destinationTransfer=$2/$destinationFolder

    # rsync create the destination folder and copy
    # -a -rlptgoD, -v verbose,
    # -r recursive, -l copy symlinks, -p preserve permissions, -t preserve times,
    # -g preserve group, -o preserve owner (root only), -D preserve devices (root only),
    # --partial keep partial copied files, --stats display stats, --progress display progress,
    # --exclude '*.*' exclude files
    logger INFO "Start rsync with source:$sourceTransfer -- destination:$destinationTransfer"
    rsync -av --partial --stats --progress \
    --exclude '.DS_Store*' --exclude '.Trashes*' --exclude '.fseventsd*' --exclude '.Spotlight*' \
    $sourceTransfer $destinationTransfer > $logs/$destinationFolder

    # catch rsync errors
    if [ "$?" -eq "0" ]
    then
        logger INFO "rsync $sourceTransfer done with sucess"
    else
        logger ERROR "Error while running rsync with code: $?"
        logger ERROR "Read rsync manual for more information: man rsync"
        logger ERROR "Not transfered or partial transfered: $sourceTransfer"
    fi

    # compare source and destination with rsync
    checksumWithRsync $sourceTransfer $destinationTransfer
}

checkDestinationSize () {
    destinationFolderForSize=$1
    percentage="0"
    while [ "$percentage" -lt "100" ]
    do
        destinationSize=`du -s $destinationFolderForSize | awk 'END{print}' | awk '{print $1}'`
        percentage=$(( destinationSize * 100 / sourceSize ))
        if [ $updateThisLog == true ]
        then
            clearLastLine
        fi
        
        echo "`date +%F"_"%H:%M:%S` INFO Waiting new volume $points"
        updateThisLog=true
        sleep 1
    done
}


# used by transferTeeTar to set the destinations
unpackInDestinations () {
    local currArg='' evalStr=''
    for dest
    do
        printf -v currArg '>(cd %q && tar xf -)' "$dest"
        evalStr+=" $currArg"
    done
    eval "tee $evalStr >/dev/null"
}

# take two parameters: $1 volume source, $2 name of the array destinations
# transfer source in destinations folder
# verify the backup with rsync checksum
transferTeeTar () {
    local sourceTransfer=$1
    local destinationsTransfer="$2[@]"

    declare -a destinationFolderArray=()

    for item in "${!destinationsTransfer}"
    do
        destinationFolder="$item/$sourceTransfer"_"`date +%F"_"%H:%M:%S`"
        mkdir $destinationFolder
        destinationFolderArray=("${destinationFolderArray[@]}" "$destinationFolder")
        logger INFO "Destination : $destinationFolder"
    done

    #sourceSize=`du -k /Volumes/$sourceTransfer/ | awk 'END{print}' | awk '{print $1}'`
    sourceSize=`find /Volumes/$sourceTransfer -type f -not -path '*/\.*' -exec ls -l {} \; | awk '{sum += $5} END {print sum}'`
    sourceNumber=`find /Volumes/$sourceTransfer  -type f -not -path '*/\.*' | wc -l`
    logJob $jobLog INFO "Number of files source: $sourceNumber"
    logJob $jobLog INFO "sourceSize: $sourceSize Bytes -> $((sourceSize / 1024 / 1024 / 1024 )) GiB"
    logger INFO "Number of files source: $sourceNumber"
    logger INFO "sourceSize: $sourceSize Bytes -> $((sourceSize / 1024 / 1024 / 1024 )) GiB"


    
    logger INFO "----    START TRANSFER    ----    START TRANSFER    ----    START TRANSFER    ----"
    logJob $jobLog INFO "----    START TRANSFER    ----    START TRANSFER    ----    START TRANSFER    ----"
    cd /Volumes/ && tar cf - $sourceTransfer/ | pv -s $((sourceSize)) | unpackInDestinations ${destinationFolderArray[@]}
    # & checkDestinationSize ${destinationArray[0]}
    logger INFO "----     END TRANSFER     ----     END TRANSFER     ----     END TRANSFER     ----"
    logJob $jobLog INFO "----     END TRANSFER     ----     END TRANSFER     ----     END TRANSFER     ----"

    # verify destination by destination with rsync and checksum

    # for item in ${destinationFolderArray[@]}
    # do
    #     sourceVerif=$watchFolder/$sourceTransfer/
    #     destinationVerif=$item/$sourceTransfer/
	   #  checksumWithRsync $sourceVerif $destinationVerif
    # done

    # launch verification
    checksumFileByFile $sourceTransfer


}

# take two parameters: $1 source, $2 destination
# try a rsync without transfer to compare source and destination
# -c checksum to compare before transfer, -n don't transfer
checksumWithRsync (){
    sourceVerif=$1
    destinationVerif=$2

    doChecksum=$(rsync -avnc --stats \
                --exclude '.DS_Store*' --exclude '.Trashes*' --exclude '.fseventsd*' --exclude '.Spotlight*' \
                $sourceVerif $destinationVerif | grep -i "Number of files transferred" | awk -F ": " '{print $2}')

    logger INFO "Number of different files: $doChecksum"

    # if number of difference equal zero
    if [ "$doChecksum" != "0" ]
    then
        logger ERROR "Checksum verification report differences between source and destination"
        logger ERROR "Not transfered or partial transfered: $sourceVerif to $destinationVerif"
    else
        logger INFO "Checksum success"
        logger INFO "Source: $sourceVerif"
        logger INFO "... has been successfully compared to ..."
        logger INFO "Destination: $destinationVerif"
    fi
}

# used by checksumFileByFile - object path and checksum of a specific file
function filePathChecksum ()
{
    # A pointer to this Class. (2)
    base=$FUNCNAME
    this=$1
 
    for class in $(eval "echo \$${this}_inherits")
    do
        for property in $(compgen -A variable ${class}_)
        do
            export ${property/#$class\_/$this\_}="${property}" # (3.2)
        done
 
        for method in $(compgen -A function ${class}_)
        do
            export ${method/#$class\_/$this\_}="${method} ${this}"
        done
    done
 
    # Declare Properties. (4)
    export ${this}_path=$2
    export ${this}_checksum=`xxhsum $2 | cut -d ' ' -f 1`
 
    # Declare methods. (5)
    for method in $(compgen -A function)
    do
        export ${method/#$base\_/$this\_}="${method} ${this}"
    done
}

# used by checksumFileByFile - object destination with path and integrity information
function destinationInfos ()
{
    # A pointer to this Class. (2)
    base=$FUNCNAME
    this=$1
 
    for class in $(eval "echo \$${this}_inherits")
    do
        for property in $(compgen -A variable ${class}_)
        do
            export ${property/#$class\_/$this\_}="${property}" # (3.2)
        done
 
        for method in $(compgen -A function ${class}_)
        do
            export ${method/#$class\_/$this\_}="${method} ${this}"
        done
    done
 
    # Declare Properties. (4)
    export ${this}_path=$2
    export ${this}_status=$3
 
    # Declare methods. (5)
    for method in $(compgen -A function)
    do
        export ${method/#$base\_/$this\_}="${method} ${this}"
    done
}


# used by checksumFileByFile - checksum the destinations
unpackDestinationFilesToChecksum () {
    local currArg='' evalStr='' i=0

    for destin
    do
        i=$((i+1))
        # codeToExecute="filePathChecksum dest$i $destin/$relativePath"
        printf -v currArg "filePathChecksum dest$i \"$destin/$relativePath\" && "       
        evalStr+=" $currArg"
    done
    eval "$evalStr >/dev/null"
}

# take one parameter: source of the verification
# check differences between source and multiple destinations
# the destination must be already set in ${destinationFolderArray[@]}
# check file by file
checksumFileByFile () {
	sourceTransfer=$1

    # provisional file list of the source
    # used later in the loop
    mkdir -p ~/report
    touch ~/report/file_list_myfile
    # build the list
    # ignore files starting by a dot, it could be more specific
    find /Volumes/$sourceTransfer -type f -not -path '*/\.*' | cut -d/ -f2- | sort > ~/report/file_list_myfile

    # create object destinationsInfos to track integrity
    i=0
    for destination in ${destinationFolderArray[@]}
    do
        i=$((i+1))
        destinationInfos 'destination'$i "$destination" "VERIFIED"
    done

    y=0
    # loop in the file list
	while read F
	do
        y=$((y+1))
        if [ $updateThisLog == true ]
        then
            clearLastLine
        fi
        
        echo "`date +%F"_"%H:%M:%S` INFO $y / $sourceNumber files"
        updateThisLog=true

        # carefull, the next line remove the two first parts of the path seperated by /
		relativePath=`echo "$F" | cut -d/ -f2-`
        logJob $jobLog INFO "File: $F"

        # calculate all the checksum, it uses xxhsum program, unpackDestinationFilesToChecksum function
		sourceChecksum=`xxhsum "/$F" | cut -d ' ' -f 1` && unpackDestinationFilesToChecksum ${destinationFolderArray[@]}

        logJob $jobLog INFO "sourceChecksum: $sourceChecksum"

        # loop in the destination to compare one by one if the checksum match with sourceChecksum
        i=0
		for destination in ${destinationFolderArray[@]}
		do
            i=$((i+1))
            logJob $jobLog INFO ""
            logJob $jobLog INFO "destination number: $i"
            
            # get the current chekcsum with the object dedicated
            currPath='$dest'$i'_path'
            currChecksum='$dest'$i'_checksum'
            currDestination='destination'$i



            printf -v currArg "$currChecksum"
            eval "currCalculatedChecksum=$currArg"

            printf -v currArg "$currPath"
            eval "currFilePath=$currArg"

            # compare checksums, report errors if it doesn't match
			if [ $sourceChecksum == $currCalculatedChecksum ] && [ ${#sourceChecksum} == 16  ]
			then	
				logJob $jobLog INFO "Status: VERIFIED successfully"
				logJob $jobLog INFO "file destination: $currFilePath"
				logJob $jobLog INFO "checksum: $currCalculatedChecksum"
            else            
                logJob $jobLog ERROR "Status: FAILED"
                logJob $jobLog ERROR "file destination: $currFilePath"
                logJob $jobLog ERROR "checksum: $currCalculatedChecksum"
                # change the status of the destinationInfo object to report the error
                printf -v currArg  "destinationInfos $currDestination $destination"
                eval "$currArg ERROR"
			fi
            
		done
        logJob $jobLog INFO "------------------------------"
        logJob $jobLog INFO ""
	done <~/report/file_list_myfile


    logJob $jobLog INFO "------------------------------"
    logJob $jobLog INFO "|     Verification ended     |"
    logJob $jobLog INFO "------------------------------"
    logJob $jobLog INFO ""
    logJob $jobLog INFO "Source: $sourceTransfer"
    logJob $jobLog INFO "source size: $sourceSize Bytes -> $((sourceSize / 1024 / 1024 / 1024 )) GiB"
    logJob $jobLog INFO "source file number: $sourceNumber files"
    logJob $jobLog INFO ""

    

    # report for each destination the destinationInfo object status
    i=0
    for destination in ${destinationFolderArray[@]}
    do
        i=$((i+1))
        logJob $jobLog INFO "Destination path: $destination"
        logJob $jobLog INFO "Destination number $i"

        currDestination='$destination'$i'_status'
        currDestinationSize=`find $destination -type f -not -path '*/\.*' -exec ls -l {} \; | awk '{sum += $5} END {print sum}'`
        currDestinationNumber=`find $destination -type f -not -path '*/\.*' | wc -l`
    	
        
        printf -v currArg "currDestination"
        eval "validated=$currDestination"

        

        if [[ $validated != "VERIFIED" ]]
        then
            logger ERROR "Verification process report error(s) restart the job or check the log at: $jobLog"
            logger ERROR "Destination error: $destination"
            logger ERROR "Destination Size: $currDestinationSize Bytes -> $((currDestinationSize / 1024 / 1024 / 1024 )) GiB"
            logger ERROR "Number of files destination: $currDestinationNumber"
            logJob $jobLog ERROR "Destination status: ERROR"
            logJob $jobLog ERROR "There are errors in the verification of this destination, check the logs above or restart the transfer"
            logJob $jobLog ERROR "Destination Size: $currDestinationSize Bytes -> $((currDestinationSize / 1024 / 1024 / 1024 )) GiB"
            logJob $jobLog ERROR "Number of files destination: $currDestinationNumber"
        else
            logger INFO "Tranfer verified with success in $destination"
            logger INFO "Destination Size: $currDestinationSize Bytes -> $((currDestinationSize / 1024 / 1024 / 1024 )) GiB"
			logger INFO "Number of files destination: $currDestinationNumber"
            logJob $jobLog INFO "Number of files destination: $currDestinationNumber"
            logJob $jobLog INFO "Destination status: SUCCESS"
            logJob $jobLog INFO "The destination has been verified with success"
            logJob $jobLog INFO "Destination Size: $currDestinationSize Bytes -> $((currDestinationSize / 1024 / 1024 / 1024 )) GiB"
        fi
        logJob $jobLog INFO ""
    done
}



# START infinite loop
while true
do
    #init
    transferProcessing=false
    # detect actual mounted volumes and send it to the volumeArray
	volumeList=`ls $watchFolder`
	declare -a volumeArray=()
	for item in $volumeList
	do
		volumeArray=("${volumeArray[@]}" "$item")
	done	

    # log actual volume and ignored arrays
    # arrayToLog=${volumeArray[@]}
    # logger TEST "actual volumeArray : $arrayToLog"
    # arrayToLog=${ignoreArray[@]}
    # logger TEST "actual ignoreVolumes : $arrayToLog"

    # delete unmonted volumes from ignored list
    for i in "${!ignoreArray[@]}"
    do
        isPresent=false
        for present in "${volumeArray[@]}"
        do
            if [[ ${ignoreArray[i]} == $present ]]
            then
                isPresent=true
            fi
        done
        if [[ $isPresent == false ]]
        then
            logger INFO "An ignored volume as been ejected: ${ignoreArray[i]}"
            unset 'ignoreArray[i]'
            arrayToLog=${ignoreArray[@]}
            logger INFO "New ignoreVolumes : $arrayToLog"
            startedDetectingVolumes=false
        fi
    done

    # delete ignored volumes from actual mounted volumes 
	for i in "${!volumeArray[@]}"
	do
		for ignored in "${ignoreArray[@]}"
		do
			if [[ ${volumeArray[i]} == $ignored ]]
			then
				unset 'volumeArray[i]'
			fi
		done
	done




    # log only when the detection start
    if [ $startedDetectingVolumes == false ]
    then
        logger INFO ""
        logger INFO "Volume detection started"
    fi
    startedDetectingVolumes=true


    # if no new volume are detected
    if [[ "${!volumeArray[@]}" == "" ]]
    then
        # points animation while waiting new volumes
        points="$points."
        ((logcount++))
        if [ $logcount -gt 3 ]
        then
            logcount=0
            points=""
        fi
        if [ $updateThisLog == true ]
        then
            clearLastLine
        fi
        echo "`date +%F"_"%H:%M:%S` INFO Waiting new volume $points"
        updateThisLog=true
    fi
    

    # copy each volumes detected to destinations
    for i in "${!volumeArray[@]}"
    do
        logger START "Volume detected: ${volumeArray[i]}"
        folderSource=${volumeArray[i]}
        sleep 1

        # create the log file used in checksumFileByFile()
        jobDate=`date +%F"_"%H:%M:%S`
        jobName="job_$jobDate"
        jobLog=$logs/$jobName.log
        touch $jobLog

        # tar transfer source to multiple destinations and verify
        transferTeeTar $folderSource destinationArray
        # add source volume to ignored volumes array and log the new array
        arrayToLog=${ignoreArray[@]}
        ignoreArray=("${ignoreArray[@]}" "$folderSource")
        arrayToLog=${ignoreArray[@]}
        logger INFO "New ignoreVolumes : $arrayToLog"
        startedDetectingVolumes=false

        # rsync transfer source to multiple destinations and verify
        # for item in $destinationList
        # do
        #     sleep 1
        #     # transferRsync function: $1 source, $2 destination
        #     transferRsync ${volumeArray[i]} $item
        #     # add source volume to ignored volumes array and log the new array
        #     ignoreArray=("${ignoreArray[@]}" "${volumeArray[i]}")
        #     arrayToLog=${ignoreArray[@]}
        #     logger INFO "New ignoreVolumes : $arrayToLog"
        #     startedDetectingVolumes=false
        # done

	done
	sleep $loopDuration
done
# END infinite loop
