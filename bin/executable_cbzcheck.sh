#!/bin/bash
#

if ! type 7za 2>&1 >/dev/null; then
	echo "Unable to find 7za.  Aborting."
	exit 1
fi

if [ -z "$1" ]; then
	echo "Usage: $0 <filename.cbz>"
	exit 1
fi

if [ ! -f "$1" ]; then
	echo "Unable to find \"$1\""
	exit 1
fi

echo "Filename: $(basename "$1")"
7za e -so "$1" ComicInfo.xml 2>/dev/null | grep -v '<?xml' | grep -v '^<\/\?ComicInfo' | sed 's/^ *//' | sed 's/[^>]*$//' | grep -v '^<\/\?Page' | sed 's/^<\([^>]*\)>\([^<].*\)<.*>$/\1: \2/'
echo "Files: $(7za l "$1" 2>/dev/null | grep -v ComicInfo.xml | grep '^[0-9]\{4\}\(-[0-9]\{2\}\)\{2\} [0-9]\{2\}\(:[0-9]\{2\}\)\{2\} \.\{5\}\( \+[0-9]\+\)\{2\} \+.*\..*' | tail -n+2 | wc -l | tr -d ' ')"
