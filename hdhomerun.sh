#!/bin/sh
###########################
# hdhomerun.sh
# Shell Script to prepare the container data and execute the record engine
# Version 1.1
#  

# Parameters - make sure these match the DockerFile
HDHR_HOME=/HDHomeRunDVR
HDHR_USER=hdhr
HDHR_GRP=hdhr
DVRData=${HDHR_HOME}/data
DVRRec=${HDHR_HOME}/recordings
DefaultPort=59090

# Download URLs from Silicondust - Shouldn't change much
DownloadURL=https://download.silicondust.com/hdhomerun/hdhomerun_record_linux
BetaURL=https://download.silicondust.com/hdhomerun/hdhomerun_record_linux_beta

# Some additional params you can change
DVRConf=dvr.conf
DVRBin=hdhomerun_record
HDHR_LOG=${DVRData}/HDHomeRunDVR.log

###########################
# Create hdhr user to run the DVR as - default to 1000:1000
#
create_hdhr_user()
{
	CURR_USR=$(id -u)
	if [ ! "$CURR_USR" eq "0"] ; then
		echo "Creating HDHR User" >> ${HDHR_LOG}
		if [ -z "$PGID" ] ; then
			PGID=1000
		fi
		if [ -z "$PUID" ] ; then
			PUID=1000
		fi

		echo "Checking $PGID exists" >> ${HDHR_LOG}
		if grep -Fq ':$PGID:' /etc/group ; then
			echo "Nope... creating Group" >> ${HDHR_LOG}
			delgroup $HDHR_GRP
			addgroup -g $PGID $HDHR_GRP
		else
			echo "Yep... Using existing group" >> ${HDHR_LOG}
			HDHR_GRP=`grep -F ':$PGID:' /etc/group | cut -d: -f1`
		fi

		echo "Checking $PUID exists" >> ${HDHR_LOG}
		if grep -Fq ':$PUID:' /etc/passwd ; then
			echo "Nope... creating User " >> ${HDHR_LOG}
			deluser $HDHR_USER
			adduser -HDG $HDHR_GRP -u $PUID $HDHR_USER
		else
			echo "Yep... Using existing User" >> ${HDHR_LOG}
			HDHR_USER=`grep -F ':$PUID:' /etc/passwd | cut -d: -f1`
		fi
	else
		echo "Running as non root user! Assume using -user on docker, skipping setup of user..." >> ${HDHR_LOG}
	fi
}


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
	echo "** Creating Initial Config File" >> ${HDHR_LOG}
	touch  ${DVRData}/${DVRConf}
	echo "RecordPath=${DVRRec}" >> ${DVRData}/${DVRConf}
	echo "Port=${DefaultPort}" >> ${DVRData}/${DVRConf}
	echo "RecordStreamsMax=16" >>  ${DVRData}/${DVRConf}
	echo "BetaEngine=1" >>  ${DVRData}/${DVRConf}
}

###########################
# Verifies the config file dvr.conf exists in /HDHomeRunDVR/data and ensure
# is writable so Engine can update the StorageID
# If the file doesnt exist, create one.
#
validate_config_file()
{
	echo "** Validating the Config File is available and set up correctly" >> ${HDHR_LOG}
	if [[ -e ${DVRData}/${DVRConf} ]] ; then
		echo "Config File exists and is writable - is record path and port correct"  >> ${HDHR_LOG}
		.  ${DVRData}/${DVRConf}
		# TODO: Validate RecordPath
		# TODO: Validate Port
	else
		# config file is missing
		echo "Config is missing - creating initial version" >> ${HDHR_LOG}
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
	echo "** Installing the HDHomeRunDVR Record Engine"  >> ${HDHR_LOG}
	echo "Lets remove any existing engine - we're going to take the latest always.... " >> ${HDHR_LOG}
	rm -f  ${DVRData}/${DVRBin}
	echo "Checking it was deleted - if we can't remove it we can't update" >>  ${HDHR_LOG}
	# TODO: check file was deleted - warn if not
	# TODO: check Beta download is enabled on config file, and only download if enabled
	echo "Downloading latest release" >> ${HDHR_LOG}
	wget -qO ${DVRData}/${DVRBin}_rel ${DownloadURL}
	if [ "$BetaEngine" -eq "1" ]; then
		echo "Downloading latest beta" >> ${HDHR_LOG}
		wget -qO ${DVRData}/${DVRBin}_beta ${BetaURL}
		echo "Comparing which is newest" >>  ${HDHR_LOG}
		if [[ ${DVRData}/${DVRBin}_rel -nt  ${DVRData}/${DVRBin}_beta ]] ; then
			echo "Release version is newer - selecting as record engine" >> ${HDHR_LOG}
			mv ${DVRData}/${DVRBin}_rel ${DVRData}/${DVRBin}
			rm ${DVRData}/${DVRBin}_beta
			chmod u+x ${DVRData}/${DVRBin}
		elif [[ ${DVRData}/${DVRBin}_rel -ot  ${DVRData}/${DVRBin}_beta ]]; then
			echo "Beta version is newer - selecting as record engine" >> ${HDHR_LOG}
			mv ${DVRData}/${DVRBin}_beta ${DVRData}/${DVRBin}
			rm ${DVRData}/${DVRBin}_rel
			chmod u+x ${DVRData}/${DVRBin}
		else
			echo "Both versions are same - using the Release version" >> ${HDHR_LOG}
			mv ${DVRData}/${DVRBin}_rel ${DVRData}/${DVRBin}
			rm ${DVRData}/${DVRBin}_beta
			chmod u+x ${DVRData}/${DVRBin}
		fi
	fi

	EngineVer=`sh ${DVRData}/${DVRBin}  version | awk 'NR==1{print $4}'`
	echo "Engine Updated to... " ${EngineVer} >>  ${HDHR_LOG}
}

###########################
# Start the engine in foreground, redirect stderr and stdout to the logfile
#
start_engine()
{
	echo "** Starting the DVR Engine as user $HDHR_USER" >> ${HDHR_LOG}
	su ${HDHR_USER} -c "${DVRData}/${DVRBin} foreground --conf ${DVRData}/${DVRConf} >> ${HDHR_LOG} 2>&1"
}

###########################
# Main loop
#
validate_config_file
update_engine
create_hdhr_user
start_engine

