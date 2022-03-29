#!/bin/bash
# Compare two directories using rsync and print the differences
# CAUTION: options MUST appear after the directories
#
# SYNTAX
#---------
# diff-dirs Left_Dir Right_Dir [options]
#
# EXAMPLE OF OUTPUT
#------------------
# L             file-only-in-Left-dir
# R             file-only-in-right-dir
# X >f.st...... file-with-dif-size-and-time
# X .f...p..... file-with-dif-perms
#
# L / R mean that the file/dir appears only at the `L`eft or `R`ight dir. 
#
# X     means that a file appears on both sides but is not the same (in which
#       case the next 11 characters give you more info. In most cases knowing
#       that s,t,T and p depict differences in Size, Time and Permissions 
#       is enough but `man rsync` has more info
#       (look at the --itemize-changes option)
#
# OPTIONS
#---------
# All options are passed to rsync. Here are the most useful for the purpose
# of directory comparisons:
#
# -c will force comparison of file contents (otherwise only
#    time & size is compared which is much faster)
#
# -p/-o/-g will force comparison of permissions/owner/group

if [[ -z $2 ]] ; then
    echo "USAGE: $0 dir1 dir2 [optional rsync arguments]"
    exit 1
fi

set -e

LEFT_DIR=$1; shift
RIGHT_DIR=$1; shift
OPTIONS="$*"

# Files that don't exist in Right_Dir
rsync $OPTIONS -rin --ignore-existing "$LEFT_DIR"/ "$RIGHT_DIR"/|sed -e 's/^[^ ]* /L             /'
# Files that don't exist in Left_Dir
rsync $OPTIONS -rin --ignore-existing "$RIGHT_DIR"/ "$LEFT_DIR"/|sed -e 's/^[^ ]* /R             /'
# Files that exist in both dirs but have differences
rsync $OPTIONS -rin --existing "$LEFT_DIR"/ "$RIGHT_DIR"/|sed -e 's/^/X /'
