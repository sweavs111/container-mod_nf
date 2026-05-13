#!/bin/bash

rm uri_output.txt

while IFS= read -r line; do
	uri=$(./get_container_uri.sh "$line" 2>/tmp/brc_err)
	if [ $? -eq 0 ]; then
		echo "$uri" >> uri_output.txt
	else
		echo "$line $(cat /tmp/brc_err)" >> uri_output.txt
	fi	
done <  std_repos_cm.txt

echo all done
