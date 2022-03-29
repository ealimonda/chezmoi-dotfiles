#!/bin/bash

### Configuration ###
# Number of screenshots to take
SCREENSHOTS=9
# mplayer executable and path
MPLAYER=mplayer
# Whether to include beginning and end
ENDPOINTS=false

### End of configuration ###

if [ ! -x "$MPLAYER" ]; then
	if which -s mplayer; then
		MPLAYER="$(which mplayer)"
	else
		echo "mplayer not found."
		exit 1
	fi
fi

if [ "$SCREENSHOTS" -lt 1 ]; then
	echo "Sorry, how many screenshots, again?"
	exit 1
fi

if [ -z "$1" ]; then
	echo "Usage: $0 <video_file>"
	exit 1
fi
FILENAME="$1"
 
# Total video length in seconds. The version of mplayer bundles with MPlayerX.app uses MPX_LENGTH instead of ID_LENGTH.
TOTAL_LENGTH=$(${MPLAYER} -identify -frames 0 -vc null -vo null -ao null "${FILENAME}" | grep _LENGTH | sed 's/.*_LENGTH=//' | sed 's/\..*//')
echo LEN: $TOTAL_LENGTH
 
# Avoid grabbing screenshots at the ends of the video.
let TOTAL_LENGTH-=4
let SLICES=${SCREENSHOTS}+1
let TIME_SLICE=${TOTAL_LENGTH}/${SLICES}
echo SLICE: $TIME_SLICE
if [ "$ENDPOINTS" == "true" ]; then
	let SCREENSHOTS+=2
	TIME_AT=2
else
	let TIME_AT=2+$TIME_SLICE
fi
 
for ((i=1; i <= SCREENSHOTS ; i++)); do
  # Create unique filename.
  PADDING=$(printf %03d ${i})
 
  # Take the screenshot.
  echo At: $TIME_AT
  ${MPLAYER} -nosound -ss ${TIME_AT} -vf screenshot -frames 1 -vo png:z=9 "${FILENAME}" > /dev/null
 
  # Increment to the next time slice.
  let TIME_AT+=${TIME_SLICE}
 
  # Move the screenshot 00000001.png to 0X.png
  mv 00000001.png ${PADDING}.png
done
