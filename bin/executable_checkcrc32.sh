#!/bin/bash
#*******************************************************************************************************************
#* Config files                                                                                                    *
#*******************************************************************************************************************
#* File:             checkcrc32.sh                                                                                 *
#* Copyright:        (c) 2011-2013 alimonda.com; Emanuele Alimonda                                                 *
#*                   Public Domain                                                                                 *
#*******************************************************************************************************************

if [ "$1" == "-r" ]; then
	RECURSIVE="yes"
	shift
else
	RECURSIVE="no"
fi

if [ $# -lt 1 ]; then
	echo "usage: $0 [-r] <filename>"
	exit
fi

ERRORS=0
WARNINGS=0
SKIPPED=0
MAXLENGTH=0

function handlefile {
	FILENAME="$1"
	NAMELENGTH="$(basename "${FILENAME}" | wc -c | sed 's/ //g')"
	if [ $NAMELENGTH -gt $MAXLENGTH ]; then
		MAXLENGTH=$NAMELENGTH
	fi
	echo -n $FILENAME
	if [ -f "$1" ]; then
		NAME_CRC="$(basename "${FILENAME}" | sed -n -e 's/.*\[\([0-9A-Fa-f]\{8\}\)\].*/\1/p' | tr '[a-f]' '[A-F]')"
		REAL_CRC="$(crc32 "${FILENAME}" | cut -d' ' -f1 | sed -n -e 's/^\([0-9A-Fa-f]\{8\}\).*$/\1/p' | tr '[a-f]' '[A-F]')"
		if [ -n "$REAL_CRC" ]; then
			if [ -n "$NAME_CRC" ]; then
				if [ "$REAL_CRC" == "$NAME_CRC" ]; then
					echo -n '  [  OK  ]'
				else
					echo -n "  [ FAIL ]: ${REAL_CRC}"
					((ERRORS++))
				fi
			else
				echo -n "  [  --  ]: ${REAL_CRC}"
				((SKIPPED++))
			fi
			echo " (${NAMELENGTH})"
		else
			echo "  [ ERR  ]: Unable to calculate crc32"
			((WARNINGS++))
		fi
	elif [ -d "$1" ]; then
		echo " [ DIR ]"
		if [ "$RECURSIVE" == "yes" ]; then
			for i in "$1"/*; do
				handlefile "$i"
			done
		fi
	else
		echo "  [ ERR  ]: File not found"
		((ERRORS++))
	fi
}

while [ $# -gt 0 ]; do
	handlefile "$1"
	shift
done

echo "Max filename length: $MAXLENGTH"
echo "Errors:              $ERRORS"
echo "Warnings:            $WARNINGS"
echo "Skipped:             $SKIPPED"

