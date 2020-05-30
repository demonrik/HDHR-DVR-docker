#!/bin/sh
###########################
# install.sh
# Shell Script to prepare the docker image
# Version 1.0

mkdir -p /HDHomeRunDVR
mkdir /dvrdata
mkdir /dvrrec
ln -s /dvrdata /HDHomeRunDVR/data
ln -s /dvrrec /HDHomeRunDVR/recordings
