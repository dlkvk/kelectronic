#!/usr/bin/python3
from __future__ import print_function
from __future__ import unicode_literals
import musicbrainzngs
import libdiscid
import sys

musicbrainzngs.set_useragent(
    "python-musicbrainzngs-example",
    "0.1",
    "https://github.com/alastair/python-musicbrainzngs/",
)

def get_tracklist(artist, album, year):
    result = musicbrainzngs.search_releases(artist=artist, release=album, limit=1)
    id = result["release-list"][0]["id"]
    
    #### get tracklist
    new_result = musicbrainzngs.get_release_by_id(id, includes=["recordings"])

    t = (new_result["release"]["medium-list"][0]["track-list"])

    with open('mdtitle.lst', 'w') as f:
        sys.stdout = f

        print(f'disc_title={album}')
        print(f'disc_performer={artist}')
        print(f'disc_year={year}')

        for x in range(len(t)):
            line = (t[x])
            print(f'track_title{line["number"]}={line["recording"]["title"]}')
            print(f'track_performer{line["number"]}={artist}')        

if __name__ == '__main__':
    ### get first release
    if len(sys.argv) > 1:
        artist, album, year = [sys.argv[1], sys.argv[2], sys.argv[3]]
        get_tracklist(artist, album, year)
    else:
        album = input("Disc Title     : ")
        artist = input("Disc Performer : ")
        year = input("Disc Year      : ")
        if not artist == "" and not album == "":
            get_tracklist(artist, album, year)
        else:
            print("Artist or Album missing")
    
