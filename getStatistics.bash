#!//bin/bash

#
# load configuration
#

if [ -f "./config/3dStatistics.ini" ]; then
   source ./config/3dStatistics.ini
else
	mkdir -p config
	(echo "thingInputFile=\"config/thingiverse.items\""
	 echo "thingApiToken=\"ENTER_YOUR_THINGIVERSE_APP_TOKEN_HERE\""
	 echo "cultsInputFile=\"cults.items\""
	 echo "resultFile=\"results/statistics.csv\"") > config/3dStatistics.ini

	chmod +x config/3dStatistics.ini

	echo "Please configure thingApiToken config/3dStatistics.ini"
	echo "Please add your things to the config/thingiverse.items file"
	echo "Please add your things to the config/cults.items file"

	if [ ! -d tmp ]; then
		mkdir tmp
		echo "tmp directory created"
	fi

	if [ ! -d results ]; then
		mkdir results
		echo "result directory created"
	fi

	echo "Date,Thingiverse,Cults Total,Prusa Total" > results/statistics.csv

	echo "results/statistics.csv initialized"

	exit
fi

#
# helper files
#

thingTmpFile="tmp/thing.out"
thingError="tmp/thingiverse.error"
thingProcessingFile="tmp/thingiverse.tmp"

cultsTmpFile="tmp/cults.out"
cultsLogFile="tmp/cults.log"
cultsError="tmp/cults.error"
cultsProcessingFile="tmp/cults.tmp"

#
# result vars
#
thingTotalDownloads=0
thingTotalDownloads=0
cultsTotalDownloads=0
prusaTotalDownloads=0

# check current files and directories
if [ ! -d tmp ]; then
	mkdir tmp
fi

if [ -f ${thingTmpFile} ]; then
	rm ${thingTmpFile}
fi

if [ -f ${thingProcessingFile} ]; then
	rm ${thingProcessingFile}
fi

if [ -f ${cultsTmpFile} ]; then
	rm ${cultsTmpFile}
fi

if [ -f ${cultsLogFile} ]; then
	rm ${cultsLogFile}
fi

if [ -f ${cultsProcessingFile} ]; then
	rm ${cultsProcessingFile}
fi

#
# downloadFilesFromThingiverse: Get download data for a list of things
#
function downloadFilesFromThingiverse {
	#
	local tmpInut="tmp/thingiverse.tmpInput"
	cp ${1} ${tmpInut}
	rm ${thingError} > /dev/null 2>&1

	# iterate over input file
	for currentUrl in `sort -u ${tmpInut}`; do

		# get thing id from URL
		thingId=`echo $currentUrl | cut -d':' -f3`

		# get thing details from API
		wgetResult=`wget -O ${thingTmpFile} -t 50 -T 120 "https://api.thingiverse.com/things/${thingId}?access_token=${thingApiToken}" 2>&1 | grep "200 OK"`
		if [ ! "X${wgetResult}" == "X" ]; then
			numberOfDownloads=`jq -r ".download_count" ${thingTmpFile}`

			thingTotalDownloads=$((thingTotalDownloads + $numberOfDownloads))

			echo -e "      ${currentUrl}\t(${numberOfDownloads})\t: OK"
		else
			echo -e "      ${currentUrl} \t\t: ERROR"
			echo ${currentUrl} >> ${thingError}
		fi
	done
}

#
# getThingStatistics: Get statistics from Thingiverse
#
function getThingiverseStatistics {

	# input file
	thingTmpInputFile=${thingInputFile}

	# cumulative number of downloads
	thingTotalDownloads=0
	thingTotalViews=0

	# print inital header
	echo "--------------------------------------------------------------------------------"
	echo "   Thingiverse:"

	# loop until no error file is available
	while : ; do
		downloadFilesFromThingiverse ${thingTmpInputFile}

		if [ -f ${thingError} ]; then
			echo "--------------------------------------------------------------------------------"
			echo "   Retrying errors"
			thingTmpInputFile=${thingError}
		else
			break
		fi
	done
}

function downloadFilesFromCults {
	#
	local tmpInut="tmp/cults.tmpInput"
	cp ${1} ${tmpInut}
	rm ${cultsError} > /dev/null 2>&1

	# iterate over input file
	for currentUrl in `sort -u ${tmpInut}`; do
		# get cults id from URL
		cultsId=`echo $currentUrl | cut -d'/' -f7`

		# get cults details from API
		# wgetResult=`wget -O ${cultsTmpFile} -t 50 -T 120 "https://api.thingiverse.com/things/${thingId}?access_token=${thingApiToken}" 2>&1 | grep "200 OK"`
		
		wgetResult=`wget -O ${cultsTmpFile} -t 50 -T 120 $currentUrl 2>&1 | grep "200 OK"`

		printf "      %-70s" $cultsId
		
		if [ ! "X${wgetResult}" == "X" ]; then
			numberOfDownloads=`grep likes ${cultsTmpFile} | grep count | grep downloads | grep -o -P '(?<=downloads&quot;:{&quot;count&quot;:).*(?=,&quot;min&quot;)'`

			cultsTotalDownloads=$((cultsTotalDownloads + $numberOfDownloads))

			printf "(%5s): %s\n" $numberOfDownloads "OK"
		else
			printf "(%5s): %s\n" "???" "OK"
			
			echo ${currentUrl} >> ${cultsError}
		fi
	done
}

#
# getCultsStatistics: Get statistics from Cults3d
#
function getCultsStatistics {
	# input file
	cultsTmpInputFile=${cultsInputFile}

	# cumulative number of downloads
	cultsTotalDownloads=0
	cultsTotalViews=0

	# print inital header
	echo "--------------------------------------------------------------------------------"
	echo "   Cults3d:"

	# loop until no error file is available
	while : ; do
		downloadFilesFromCults ${cultsTmpInputFile}

		if [ -f ${cultsError} ]; then
			echo "--------------------------------------------------------------------------------"
			echo "   Retrying errors"
			cultsTmpInputFile=${cultsError}
		else
			break
		fi
	done
}

#
# getPrusaStatistics: Get statistics from Cults3d
#
function getPrusaStatistics {
	echo "--------------------------------------------------------------------------------"
	echo "    PrusaPrinters: "

	printf "      Value from Prusa: "
	read prusaTotalDownloads
}

function writeResults {
	echo "--------------------------------------------------------------------------------"
	echo "    Results: "
	printf "      %6d, Thingiverse total\n" ${thingTotalDownloads}
	printf "      %6d, Cults total\n" ${cultsTotalDownloads}
	printf "      %6d, Prusa total\n" ${prusaTotalDownloads}

	today=`date "+%Y.%m.%d"`
	echo "${today},${thingTotalDownloads},${cultsTotalDownloads},${prusaTotalDownloads}" >> ${resultFile}
}

getPrusaStatistics
getCultsStatistics
getThingiverseStatistics

writeResults

