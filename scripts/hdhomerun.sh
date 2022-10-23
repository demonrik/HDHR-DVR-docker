#!/bin/sh
###########################
# hdhomerun.sh
# Shell Script to prepare the container data and execute the record engine
# Version 1.2
#  

# Parameters - make sure these match the DockerFile
HDHR_HOME=/HDHomeRunDVR
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
	curEngineVer=`${DVRData}/${DVRBin} version | awk 'NR==1{print $4}'`
	stableEngineVer=""
	betaEngineVer=""
	echo ${DVR_PFX} "** Current Engine Version is $curEngineVer"
	gotStableDVR = false
	gotBetaDVR = false

	echo ${DVR_PFX} "Downloading latest Stable release"
	wget -qO ${DVRData}/${DVRBin}_rel ${DownloadURL}
	if [ $# -ne 0 ] ; then
		echo ${DVR_PFX} "ERROR in downloading latest Stable DVR binary [$#]"
	else
		stableEngineVer=`${DVRData}/${DVRBin}_rel version | awk 'NR==1{print $4}'`
		gotStableDVR = true
	fi

	if [ "$BetaEngine" -eq "1" ]; then
		echo ${DVR_PFX} "Downloading latest Beta release"
		wget -qO ${DVRData}/${DVRBin}_beta ${DownloadURL}
		if [ $# -ne 0 ] ; then
			echo ${DVR_PFX} "ERROR in downloading latest Beta DVR binary [$#]"
		else
			betaEngineVer=`${DVRData}/${DVRBin}_beta version | awk 'NR==1{print $4}'`
			gotBetaDVR = true
		fi
	fi

	if [ "$gotStableDVR" = false ] && [ "$gotBetaDVR" = false ]; then
		echo ${DVR_PFX} "ERROR have no downloaded engines - leaving the existing binary [$curEngineVer] alone!"
		return 
	elif [ "$gotBetaDVR" = true ] ; then
		echo ${DVR_PFX} "Beta version downloaded - will use this engine [$betaEngineVer]"
		rm -f  ${DVRData}/${DVRBin}
		mv ${DVRData}/${DVRBin}_beta ${DVRData}/${DVRBin}
	else # gotStableDVR = true && gotBetaDVR = false
		echo ${DVR_PFX} "Stable version downloaded - will use this engine [$stableEngineVer]"
		rm -f  ${DVRData}/${DVRBin}
		mv ${DVRData}/${DVRBin}_rel ${DVRData}/${DVRBin}
	fi
	rm ${DVRData}/${DVRBin}_beta
	rm ${DVRData}/${DVRBin}_rel
	chmod u+rwx ${DVRData}/${DVRBin}
	EngineVer=`${DVRData}/${DVRBin} version | awk 'NR==1{print $4}'`
	echo ${DVR_PFX} "Engine Updated to... " ${EngineVer}
}

###########################
# Patch Permissions to the dvr user
#
patch_permissions()
{
	echo ${DVR_PFX} "** Checking for PUID"
	/usr/bin/getent passwd ${PUID} > /dev/null
    if [ $? -eq 0 ] ; then
		echo ${DVR_PFX} "** PUID user exists - adjusting permissions to dvrdata & dvrrec"
		chown -R dvr:dvr /dvrdata /dvrrec
	else
		echo ${DVR_PFX} "** Something went wrong - PUID provided, but no user created. using default"
	fi
}

###########################
# Start the engine in foreground, redirect stderr and stdout to the logfile
#
start_engine()
{
	echo ${DVR_PFX} "** Starting the DVR Engine"
    if [ ! -z "${PUID}" ] || [ ! -z "${PGID}"] ; then
		patch_permissions
		/usr/bin/getent passwd ${PUID} > /dev/null
	    if [ $? -eq 0 ] ; then
			echo ${DVR_PFX} "** Executing DVR engine with PUID info..."
			su -c "${DVRData}/${DVRBin} foreground --conf ${DVRData}/${DVRConf}" dvr
		else
			echo ${DVR_PFX} "** Something went wrong - PUID provided, but no user created. using default"
			${DVRData}/${DVRBin} foreground --conf ${DVRData}/${DVRConf}
		fi
	else
		${DVRData}/${DVRBin} foreground --conf ${DVRData}/${DVRConf}
	fi
}

###########################
# Main loop
#
validate_config_file
update_engine
start_engine

