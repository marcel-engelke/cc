#!/bin/sh

n=$(grep -m 1 'computer' < .local/ids.json | sed 's/[^0-9]//g')

for i in $(seq 0 $n); do
	rm -rf .local/computer/$i
done
