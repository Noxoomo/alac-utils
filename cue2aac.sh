#!/bin/bash

#
# Cuesheet encoding auto-fix settings.
#
# cue2alac will try to automatically fix possible wrong (non UTF-8) encoding with 'enca' program (if it is installed).
# Please set your language preference for enca here.
#
ENCA_LANGUAGE='ru'

usage()
{
echo "usage: cue2alac <cuefile>"
}

program_exists ()
{
type "$1" &> /dev/null ;
}

metadata()
{
local cue_file="$1"
local field="$2"
echo `cueprint -n $track -t "$field" "$cue_file"`
}

convert()
{
local cue_file="$1"
local track=$2
local infile="$3"
local dir="$4"
local date="$5"
local genre="$6"

local title="$(metadata "$cue_file" "%t")"
local album_artist="$(metadata "$cue_file" "%P")"
local artist="$(metadata "$cue_file" "%p")"

local outfile=`echo "$track - $title.m4a" | sed 's#\/#-#g'`
outfile="$dir/$outfile"

if [ -z "$artist" ] && [ -n "$album_artist" ]; then
artist="$album_artist"
album_artist=""
fi
#!/bin/sh
echo "Converting $infile to $outfile ..."

ffmpeg -v error -i "$infile" -c:a libfdk_aac -vbr 5   \
-metadata title="$title" \
-metadata artist="$artist" \
-metadata album_artist="$album_artist" \
-metadata album="$(metadata "$cue_file" "%T")" \
-metadata composer="$(metadata "$cue_file" "%c")" \
-metadata date="$date" \
-metadata track="$track" \
-metadata genre="$genre" \
"$outfile"
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

if ! program_exists shnsplit; then
echo "Please install shntool"
exit 1
fi

if ! program_exists cueprint; then
echo "Please install cuetools"
exit 1
fi

if [ -z "$1" ]; then
usage
exit
fi

local cue_file="$1"

mkdir -p tmp

#
# Try to automatically fix possible non-UTF-8 encoding in cuefile
#

if program_exists enca && [ -n "$ENCA_LANGUAGE" ] ; then
echo "Trying to auto-convert $cue_file to UTF-8 ..."
enca -L "$ENCA_LANGUAGE" -x UTF-8 < "$cue_file" > "tmp/$cue_file"
elif program_exists iconv; then
local encoding=`file --mime "$cue_file" | sed 's/^[^:]*: .*set=\(.*\)/\1/'`
echo "Trying to auto-convert $cue_file to UTF-8 ..."
iconv -f "$encoding" -t UTF-8 "$cue_file" > "tmp/$cue_file"
else
cp "$cue_file" "tmp/$cue_file"
fi

cue_file="tmp/$cue_file"
if program_exists dos2unix; then
dos2unix "tmp/$cue_file"
fi

#
# Get some metadata from cuefile
#

local music_file=`sed -n 's#^FILE "\(.*\)".*$#\1#p' "$cue_file"`
local date=`sed -n -e 's#^REM DATE \(.*\)$#\1#p' "$cue_file"`
date=`echo "$date" | sed 's#\"##g'`
local genre=`sed -n -e 's#^REM GENRE \(.*\)#\1#p' "$cue_file"`
genre=`echo $genre | sed 's#\"##g'`

#
# If source music file is APE, convert first it to FLAC, because shnsplit can't split APE
#

ext=`echo "${music_file: -4}" | tr "[:upper:]" "[:lower:]"`
if [ "$ext" == ".ape" ]; then
local music_file_tmp="${music_file/%ape/flac}"
echo "Converting $music_file to $music_file_tmp ..."
ffmpeg -v warning -i "$music_file" "tmp/$music_file_tmp"
music_file="tmp/$music_file_tmp"
fi

#
# Perform splitting to separate FLAC files
#

shnsplit -d tmp -f "$cue_file" -o flac -t '%n' "$music_file"

if [ -n "$music_file_tmp" ]; then
echo "Removing temporary file $music_file_tmp ..."
rm -rf "$music_file_tmp"
fi

rm -f tmp/00.flac

#
# Convert each FLAC file to ALAC + tag them
#

for file in tmp/*.flac; do
local track="${file/.flac/}"
track="${track/tmp\//}"
convert "$cue_file" $track "$file" "tmp" "$date" "$genre"
done

echo "Moving files ..."
mv tmp/*.m4a .

#
# Delete temp stuff
#

echo "Removing temporary files ..."
rm -rf tmp

echo "Done!"
}

main "$@"
