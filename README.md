# HDHR-DVR-docker
Docker Wrapper for SiliconDust's HDHomeRun DVR Record Engine

Image based no Alpine Linux https://alpinelinux.org/

Contains a script to download the latest engine when the engine is started.  
To update the engine stop the container and then start it again and it will get the latest.

Is important for HDHomeRun system to have everything on the same Network.  
thus run the container with the host network selected, i.e.
```
--network host
```

In addition to the DVR engine, the container also has an embedded NGINX web server with PHP FPM configured to deliver a simple Management GUI.
By default the Web server will run on Port 80. Use the DVRUI_PORT environment variable to move this
to a free port in the case where there is a conflict with another container, or the host.

At this time the container creates a user and group called dvr which is mapped to UID/GID=1000
The plan is to make this overrideable via environment variable in the very near future. In the meantime please ensure the volumes are accessible and writable by such a user mapping.

## Volumes
| Volume | Description |
| --------| ------- |
| dvrrec | Recordings and the engine logs will be stored here |
| dvrdata | Temporary data such as the engine itself, the config file, and a log output of the containers script |

## Environment Variables
| Variable | Description |
| --------| ------- |
| DVRUI_PORT | Override the default portof 80 for the embedded NGINX Server |


## Docker Run
```
docker run -d --name dvr \
  --restart=unless-stopped \
  --network host \
  -e DVRUI_PORT=10080 \
  -v /path/to/hdhomerun/tempdata:/dvrdata \
  -v /path/to/hdhomerun/recordings:/dvrrec \
  demonrik/hdhrdvr-docker
```