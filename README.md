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

You can override the user ID and group ID used by the container processes by setting the PUID/PGID to match a user on your system.
By default NGINX will run as a user 'nginx'' and PHP as 'nobody' while the DVR will run simply as root or mapped if you use the --user settings of docket.
If specified - then everything in /dvrdata and /dvrrec will be changed to the new user IDs.

## Updating
At this time there isn't much stored in the /dvrdata that needs to persist through an update.
Yes it would be useful to maintain the Storage UUID in the dvr.conf, but is safe to pretty much delete everything in the /dvrdata between updates (with a container stop and start) and it will be reconstructed on start. You may just need to update the params once more if you change from defaults. 

## Volumes
| Volume | Description |
| --------| ------- |
| dvrrec | Recordings and the engine logs will be stored here |
| dvrdata | Temporary data such as the engine itself, the config file, and a log output of the containers script |

## Environment Variables
| Variable | Description |
| --------| ------- |
| DVRUI_PORT | Override the default port of 80 for the embedded NGINX Server |
| PUID | Override the default user ID for the DVR |
| PGID | Override the default group ID for the DVR |


## Docker Run Example
```
docker run -d --name dvr \
  --restart=unless-stopped \
  --network host \
  -e DVRUI_PORT=10080 \
  -e PUID=1000 \
  -e PGID=1000 \
  -v /path/to/hdhomerun/tempdata:/dvrdata \
  -v /path/to/hdhomerun/recordings:/dvrrec \
  demonrik/hdhrdvr-docker
```