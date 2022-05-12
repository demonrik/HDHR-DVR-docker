#!/bin/sh
###########################
# hdhomerun.sh
# Shell Script to prepare the container data and execute the record engine
# Version 1.2
#  

# Parameters - make sure these match the DockerFile
HDHR_HOME=/HDHomeRunDVR
HDHR_USER=dvr
HDHR_GRP=dvr
DVRData=${HDHR_HOME}/data
DVRRec=${HDHR_HOME}/recordings
DefaultPort=59090

# Download URLs from Silicondust - Shouldn't change much
DownloadURL=https://download.silicondust.com/hdhomerun/hdhomerun_record_linux
BetaURL=https://download.silicondust.com/hdhomerun/hdhomerun_record_linux_beta

# Some additional params you can change
DVRConf=dvr.conf
DVRBin=hdhomerun_record
DVR_PFX="DVRMgr: "

###########################
# Creates the initial config file for the engine 8in /HDHomeRunDVR/data
# Sets Following defaults
#   RecordPath =  /HDHomeRunDVR/recordings  # Should always be this
#   Port = 59090                            # must match the Dockerfile
#   RecordStreamsMax=16                     # Enable max recordings
#   BetaEngine=1                            # Used by this script
#
create_initial_config()
{
	echo ${DVR_PFX} "** Creating Initial Config File"
	touch  ${DVRData}/${DVRConf}
	echo "RecordPath=${DVRRec}" >> ${DVRData}/${DVRConf}
	echo "Port=${DefaultPort}" >> ${DVRData}/${DVRConf}
	echo "RecordStreamsMax=16" >>  ${DVRData}/${DVRConf}
	echo "BetaEngine=1" >>  ${DVRData}/${DVRConf}
	chown ${HDHR_USER}:${HDHR_GRP} ${DVRData}/${DVRConf}
}

###########################
# Verifies the config file dvr.conf exists in /HDHomeRunDVR/data and ensure
# is writable so Engine can update the StorageID
# If the file doesnt exist, create one.
#
validate_config_file()
{
	echo ${DVR_PFX} "** Validating the Config File is available and set up correctly"
	if [[ -e ${DVRData}/${DVRConf} ]] ; then
		echo ${DVR_PFX} "Config File exists and is writable - is record path and port correct"
		.  ${DVRData}/${DVRConf}
		# TODO: Validate RecordPath
		# TODO: Validate Port
	else
		# config file is missing
		echo ${DVR_PFX} "Config is missing - creating initial version"
		create_initial_config
	fi
}

###########################
# Get latest Record Engine(s) from SiliconDust, and delete any previous
# Will get Beta (if enabled in conf) and released engine and compare dates
# and select the newest amnd make it the default
#
update_engine()
{
	echo ${DVR_PFX} "** Installing the HDHomeRunDVR Record Engine"
	echo ${DVR_PFX} "Lets remove any existing engine - we're going to take the latest always.... "
	rm -f  ${DVRData}/${DVRBin}
	echo ${DVR_PFX} "Checking it was deleted - if we can't remove it we can't update"
	# TODO: check file was deleted - warn if not
	# TODO: check Beta download is enabled on config file, and only download if enabled
	echo ${DVR_PFX} "Downloading latest release"
	wget -qO ${DVRData}/${DVRBin}_rel ${DownloadURL}
	if [ "$BetaEngine" -eq "1" ]; then
		echo ${DVR_PFX} "Downloading latest beta"
		wget -qO ${DVRData}/${DVRBin}_beta ${BetaURL}
		echo ${DVR_PFX} "Comparing which is newest"
		if [[ ${DVRData}/${DVRBin}_rel -nt  ${DVRData}/${DVRBin}_beta ]] ; then
			echo ${DVR_PFX} "Release version is newer - selecting as record engine"
			mv ${DVRData}/${DVRBin}_rel ${DVRData}/${DVRBin}
			rm ${DVRData}/${DVRBin}_beta
			chmod u+x ${DVRData}/${DVRBin}
			chown ${HDHR_USER}:${HDHR_GRP} ${DVRData}/${DVRBin}
		elif [[ ${DVRData}/${DVRBin}_rel -ot  ${DVRData}/${DVRBin}_beta ]]; then
			echo ${DVR_PFX} "Beta version is newer - selecting as record engine"
			mv ${DVRData}/${DVRBin}_beta ${DVRData}/${DVRBin}
			rm ${DVRData}/${DVRBin}_rel
			chmod u+x ${DVRData}/${DVRBin}
			chown ${HDHR_USER}:${HDHR_GRP} ${DVRData}/${DVRBin}
		else
			echo ${DVR_PFX} "Both versions are same - using the Release version"
			mv ${DVRData}/${DVRBin}_rel ${DVRData}/${DVRBin}
			rm ${DVRData}/${DVRBin}_beta
			chmod u+x ${DVRData}/${DVRBin}
			chown ${HDHR_USER}:${HDHR_GRP} ${DVRData}/${DVRBin}
		fi
	else
		echo ${DVR_PFX} "Not using Beta Versions - defaulting to Release Version"
		mv ${DVRData}/${DVRBin}_rel ${DVRData}/${DVRBin}
		chmod u+x ${DVRData}/${DVRBin}
		chown ${HDHR_USER}:${HDHR_GRP} ${DVRData}/${DVRBin}
	fi

	EngineVer=`sh ${DVRData}/${DVRBin} version | awk 'NR==1{print $4}'`
	echo ${DVR_PFX} "Engine Updated to... " ${EngineVer}
}

###########################
# Start the engine in foreground, redirect stderr and stdout to the logfile
#
start_engine()
{
	echo ${DVR_PFX} "** Starting the DVR Engine as user $HDHR_USER"
	su ${HDHR_USER} -c "${DVRData}/${DVRBin} foreground --conf ${DVRData}/${DVRConf}"
}

###########################
# Main loop
#
validate_config_file
update_engine
start_engine

