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

## Volumes
| Volume | Description |
| --------| ------- |
| dvrrec | Recordings and the engine logs will be stored here |
| dvrdata | Temporary data such as the engine itself, the config file, and a log output of the containers script |

## Docker Run
```
docker run -d --name dvr \
  --restart=unless-stopped \
  --network host \
  -v /path/to/hdhomerun/tempdata:/dvrdata \
  -v /path/to/hdhomerun/recordings:/dvrrec \
  demonrik/hdhrdvr-docker
```