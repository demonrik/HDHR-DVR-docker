# Dockerfile for HDHomeRun DVR
# The initial container will create a base Alpine Linux image and install
# runtime script which will download the latest record engine, configure it
# if no config already exists and then start the engine.
# To update the record engine, simply stop the container, and restart

# Base Image to use
FROM alpine:latest

# Build up new image
COPY install.sh /
RUN /bin/sh /install.sh
COPY hdhomerun.sh /HDHomeRunDVR

# Set Volumes to be added
VOLUME ["/dvrrec", "/dvrdata"]

# Will use this port for mapping engine to the outside world
EXPOSE 59090

# And setup to run by default
ENTRYPOINT ["/bin/sh","/HDHomeRunDVR/hdhomerun.sh"]