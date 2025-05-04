# Camera Deployments

For testing of the project, we simulated security cameras by first pulling footage from a publically-available source, preparing that footage for transmit, and then sending the footage over the Internet via a secure Wireguard VPN tunnel. This was all accomplished using ffmpeg. We can break down the flow of this process with this picture:

![Diagram of ffmpeg input-output](docs/images/ffmpeg-diagram.png)

## Getting Footage ##

Earthcam.com has feeds of public cameras freely available on its website. In order to retrieve this footage we need to inspect the page of the camera we want and find the corresponding element.

If we press f12 in our browser while on the page we want, we can find the *.m3u8 request of the footage and headers. We will re-use the user agent, request headers and path to .m3u8 in our final ffmpeg command, since Earthcam.com requires a regular-looking user agent as well as Origin and Referer fields set to https://www.earthcam.com.

## Processing Footage ##

To preserve bandwidth it is necessary to encode the footage before transmitting. If your system and build of ffmpeg includes hardware encoding, it will speed this process up drastically, but I ran the commands here in a VM with no hardware passthrough and still found the software encoding option to be sufficient with 4 vCPUs and 3 camera streams transmitting simultaneously.

I encoded the footage at 720p resolution, 800kbps bitrate, with the "ultrafast" preset for the sample. You may want to tweak those settings if it is necessary to do any computer vision processing on the NVR.

## Output of Footage: RTMP vs HLS vs MPEG-TS ##

There are many different transmission protocol choices, each with different benefits and disadvantages. Three of the most popular are RTMP, HLS, and MPEG-TS. We had the most success using MPEG-TS in our project, but do some research and modify the command below to match your requirements.

Instead of pushing the footage upstream to a listening NVR server, we had the most success with setting up ffmpeg itself to listen for http connections, while the NVR would pull the footage from the service.

## FFmpeg command ##

```bash
#!/bin/bash

ffmpeg -user_agent "Mozilla/5.0 (X11; Linux x86_64; rv:138.0) Gecko/20100101 Firefox/138.0" \
-headers "Origin: https://www.earthcam.com\r\nReferer: https://www.earthcam.com/\r\nAccept-Language: en-US,en;q=0.5\r\n" \
-i "https://videos-#.earthcam.com/path/to/playlist.m3u8" \
-vf "scale=1280:720" \
-c:v libx264 \
-preset ultrafast \
-tune zerolatency \
-b:v 800k \
-an \
-f mpegts \
-listen 1 http://ip-of-camera:port/path
```

Here's an explanation of the different flags and what they do:

#### Input Flags ####
| Flag | Description |
| ---------- | ----------- |
| -headers   | The HTTP request headers we will send to the server |
| -i   | The input file URI |

#### Encoding Flags ####
| Flag | Description |
| ---------- | ----------- |
| -vf  | Sets video filters, in this case resolution |
| -c:v | Sets the video codec |
| -preset | x264 codec has different preset options, choose it with this |
| -tune | Tuning of encoding parameters |
| -b:v | set the output video bitrate |
| -an | ignore audio if source includes any, it won't be necessary |

#### Output Flags ####
| Flag | Description |
| ---------- | ----------- |
| -f | The output stream format |
| -listen 1 | Tell ffmpeg to listen for clients to this stream |
| http://ip-of-camera:port/path | The output. Could be a file, or URI of listening server, in this case ffpmeg listens for connections on this ip and port |

## Improvements ##

Unfortunately, this method is not the most reliable because the ffmpeg process will terminate if either the NVR or footage source closes a connection. In a real-world scenario the footage source would be a real camera that would not close its connection so that would not be a problem unless there was a problem with the camera. The ffmpeg-to-nvr problem could be solved by running an nginx reverse proxy on the same host as the ffmpeg process, so that even if there is a disruption to internet service, the ffmpeg process will continue transmitting to nginx, while nginx will automatically begin forwarding footage to the NVR again once services are restored.
