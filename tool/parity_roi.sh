#!/bin/sh
set -eu
if [ "$#" -ne 7 ]; then
  echo 'Usage: sh tool/parity_roi.sh VIDEO NEW_OUTPUT_DIR X Y WIDTH HEIGHT FPS' >&2
  exit 2
fi
video=$1
destination=$2
shift 2
for dimension in "$@"; do
  case "$dimension" in ''|*[!0-9]*) echo 'Crop and FPS must be integers' >&2; exit 2;; esac
done
[ "$3" -gt 0 ] && [ "$4" -gt 0 ] && [ "$5" -gt 0 ]
dimensions=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$video")
video_width=${dimensions%,*}
video_height=${dimensions#*,}
if [ "$(($1 + $3))" -gt "$video_width" ] || [ "$(($2 + $4))" -gt "$video_height" ]; then
  echo 'ROI lies outside the recorded frame. Refusing an implicitly clamped crop.' >&2
  exit 2
fi
native_rate=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=nw=1:nk=1 "$video")
if ! printf '%s\n' "$native_rate" | awk -F/ -v requested="$5" 'NF == 2 && $2 > 0 { valid = requested <= $1 / $2 } END { exit !valid }'; then
  echo 'Requested FPS exceeds native capture cadence. Upsampling cannot establish motion fidelity.' >&2
  exit 2
fi
mkdir "$destination"
ffprobe -v error -show_streams -show_format -of json "$video" > "$destination/video.json"
ffmpeg -nostdin -v error -i "$video" -vf "crop=$3:$4:$1:$2,fps=$5" -fps_mode passthrough "$destination/frame_%06d.png"
printf '%s\n' 'Frames extracted without scaling. Keep video.json, source video and the event timeline.'
