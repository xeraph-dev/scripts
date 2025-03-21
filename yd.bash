#!/usr/bin/env bash
# Copyright 2025 xeraph. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# yt-dlp bash/zsh wrapper

cmd=yt-dlp
format=video
quality=720
type=single
url=
items=
start=
ext=bestvideo

while [[ $# -gt 0 ]]; do
    case $1 in
    h | help)
        echo "\
usage: yd [type] [format] [quality] [url]
type    = single (default) | playlist
format  = format | subtitles | audio | video (default)
quality = 144p | 240p | 360p | 480p | 720p (default) | 1024p

options:
-i --items  Specify which items of a playlist to download (e.g., '1-3,7,10')
-s --start  Specify from which item of a playlist start to download (e.g., '3')
-e --ext    Specify the extension format for video downloads (e.g., 'mp4', 'mkv')
"
        exit 0
        ;;
    f | format)
        format=format
        shift
        ;;
    a | audio)
        format=audio
        shift
        ;;
    v | video)
        format=video
        shift
        ;;
    subs | subtitles)
        format=subtitles
        shift
        ;;
    144p | 240p | 360p | 480p | 720p | 1024p)
        quality="${1%p}"
        shift
        ;;
    s | single)
        type=single
        shift
        ;;
    p | playlist)
        type=playlist
        shift
        ;;
    -i | --items)
        shift
        items=$1
        shift
        ;;
    -s | --start)
        shift
        start=$1
        shift
        ;;
    -e | --ext)
        shift
        ext=$1
        shift
        ;;
    *)
        url=$1
        shift
        ;;
    esac
done

case $format in
format)
    cmd+=" --list-formats"
    ;;
subtitles)
    cmd+=" --write-auto-sub --sub-format 'best' --sub-lang 'en,es' --skip-download"
    ;;
audio)
    cmd+=" --format 'bestaudio' --embed-chapters"
    ;;
video)
    cmd+=" --format '${ext}[height<=${quality}]+bestaudio' --embed-subs --embed-thumbnail --embed-chapters --write-auto-sub --sub-format 'best' --sub-lang 'en,es'"
    ;;
esac

if [[ $format != format ]]; then
    case $type in
    single)
        cmd+=" --no-playlist --output '$HOME/Movies/youtube-dl/%(uploader)s/%(title)s.%(ext)s'"
        ;;
    playlist)
        cmd+=" --output '$HOME/Movies/youtube-dl/%(uploader)s/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s'"
        ;;
    esac
fi

if [[ -n "$items" ]]; then
    cmd+=" --playlist-items $items"
fi

if [[ -n "$start" ]]; then
    cmd+=" --playlist-start $start"
fi

if [ -z "$url" ]; then
    echo "Missing url"
    exit 1
fi

cmd+=" '$url'"

echo $cmd
eval $cmd
