#!/bin/bash

dir=$(dirname $0)/__finderlabel
$dir/venv/bin/python $dir/finderlabel.py "$@"
