#!/bin/sh
###########################
# install.sh
# Shell Script to prepare the docker image
# Version 1.1

# Install working wget which preserves server timestamp
apk update
apk add wget
apk add grep 

# Create default user and group
addgroup -g 1000 hdhr
adduser -HDG hdhr -u 1000 hdhr

# Create working directory
mkdir -p /HDHomeRunDVR

# Create volume mount points
mkdir /dvrdata
mkdir /dvrrec

# Link to where the runtime script expects them
ln -s /dvrdata /HDHomeRunDVR/data
ln -s /dvrrec /HDHomeRunDVR/recordings
