#!/bin/bash

# list files not hiden in a directory
# process checksum on each files
# show time and bitrate to do checksum

# it needs xxhsum
# install brew:
# /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
# install xxhsum:
# brew install xxhash


# parameters
listOfFile="~/report/file_list_myfile"

echo "--------------------------------------------"
echo "--- Lets Start, read folder calculation! ---"
echo "--------------------------------------------"
echo ""
echo "Please, Drag and drop your folder."
read answer
#LIST=`find $answer -type f -not -path '*/\.*' `

touch ~/report/file_list_myfile
find $answer -type f -not -path '*/\.*' | cut -d/ -f2- | sort > ~/report/file_list_myfile

TOTALSIZE=0
IFS="$(printf '\n\t')"

while read F  ; do
	echo $F
	size2=`stat -f "%z" "/$F"`
	echo "size2 is $size2 bytes"
	TOTALSIZE=$(($TOTALSIZE+$size2))
done <~/report/file_list_myfile

echo ""
echo "Total size" $TOTALSIZE
echo ""
datestart=`date +%F"_"%H-%M-%S`
START_TIME=$SECONDS

while read F  ; do
	xxhsum /$F
	# xxhash /$F
done <~/report/file_list_myfile



dateend=`date +%F"_"%H-%M-%S`
ELAPSED_TIME=$(($SECONDS - $START_TIME))

echo ""
echo "--------------"
echo "--- RESULT ---"
echo "--------------"
echo "Date de debut" $datestart
echo "Date de fin" $dateend
echo "Secondes Ecoulées" $ELAPSED_TIME
minuteelapsed=$(($ELAPSED_TIME/60))
minuteelapsedfois60=$((60*$minuteelapsed))
secondeminuteelapsed=$(($ELAPSED_TIME-$minuteelapsedfois60))
echo "Minutes écoulées" $minuteelapsed "+" $secondeminuteelapsed "secondes"

debit=$(($TOTALSIZE/$ELAPSED_TIME))
echo "debit en B/s" $debit
debitm=$(($debit/1000000))
echo "debit en MB/s" $debitm
echo "Taille totale" $TOTALSIZE
