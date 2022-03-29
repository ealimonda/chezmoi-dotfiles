#!/usr/bin/python
#*******************************************************************************************************************
#* Scripts                                                                                                         *
#*******************************************************************************************************************
#* File:             crc32sum.py                                                                                   *
#* Copyright:        (c) 2011-2012 alimonda.com; Emanuele Alimonda                                                 *
#*                   Public Domain                                                                                 *
#*******************************************************************************************************************

import sys, re, zlib

c_null="[00;00m"
c_red="[31;01m"
c_green="[32;01m"

def crc32_checksum(filename):
	filedata = open(filename, "rb").read()
	sum = zlib.crc32(filedata)
	if sum < 0:
		sum &= 16**8-1
	return "%.8X" %(sum)

if len(sys.argv) >= 2 and sys.argv[1] == "-s":
	sys.argv.pop(1)
	mode = "simple"
else:
	mode = "full"

for file in sys.argv[1:]:
	sum = crc32_checksum(file)
	if mode == "simple":
		print "%s" %(sum)
	else:
		try:
			dest_sum = re.split('[\[\]]', file)[-2]
			dest_sum = re.search('[\[(][\dA-F]{8}[\])]', file).group()[1:-1]
			if sum == dest_sum:
				c_in = c_green
			else:
				c_in = c_red
			sfile = file.split(dest_sum)
			print "%s%s%s   %s%s%s%s%s" % (c_in, sum, c_null, sfile[0], c_in, dest_sum, c_null, sfile[1])
		except AttributeError:
			print "%s   %s" %(sum, file)
		except IndexError:
			print "%s   %s" %(sum, file)

