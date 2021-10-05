#! /bin/bash
YOUTUBE_LIVE_STREAM=https://www.youtube.com/watch?v=AdUw5RdyZxI

apt-get update
apt-get install nginx-light ffmpeg -y
curl -LO https://yt-dl.org/downloads/latest/youtube-dl
chmod 755 youtube-dl
ln -sf `which python3` /usr/bin/python

fmt=`./youtube-dl --list-formats $YOUTUBE_LIVE_STREAM | grep -E "^[0-9]+\s" | tail -4 | head -1 | tr -s ' ' | cut -d' ' -f1`
src=`./youtube-dl -f $fmt -g $YOUTUBE_LIVE_STREAM`


cat <<EOF >/var/www/html/index.nginx-debian.html
<link href="https://vjs.zencdn.net/7.15.4/video-js.css" rel="stylesheet" />
<script src="https://vjs.zencdn.net/7.15.4/video.min.js"></script>
<div>Youtube live-stream: <a href=$YOUTUBE_LIVE_STREAM target=_blank>$YOUTUBE_LIVE_STREAM</a></div>
<br><br>
<video id=hls class=video-js controls>
  <source src="index.m3u8" type="application/x-mpegURL">
</video>
<script>videojs('hls').play()</script>
EOF

cd /var/www/html && \
ffmpeg -i $src -c copy -f hls \
    -hls_time 10 \
    -hls_list_size 10 \
    -hls_segment_type mpegts \
    -hls_segment_filename data%06d.ts \
    index.m3u8 </dev/null >/dev/null 2>&1 &

(sleep 30m && pkill ffmpeg) &
