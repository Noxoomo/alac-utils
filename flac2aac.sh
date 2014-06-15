#!/bin/bash

usage()
{
	echo "usage: flac2alac — converts all flac files in directory to aac"
}

program_exists ()
{
	type "$1" &> /dev/null ;
}

main()
{
	set -e

	if ! program_exists ffmpeg; then
		echo "Please install ffmpeg"
		exit 1
	fi

	if ! program_exists metaflac; then
		echo "Please install flac"
		exit 1
	fi
	for file in *.flac
	do
	
		local infile="$file"
		local outfile="${infile/%flac/m4a}"
		local album_artist=$(metaflac --show-tag='ALBUM ARTIST' "$infile" | sed 's/ALBUM ARTIST=//g')

		echo "Converting $infile to $outfile ..."
	
		ffmpeg -i "$infile" -c:a libfdk_aac -b:a 300k -cutoff 1800 -metadata album_artist="$album_artist" "$outfile"
	done
}

main "$@"

