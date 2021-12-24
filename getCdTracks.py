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

this_disc = libdiscid.read(libdiscid.default_device())
release = musicbrainzngs.get_releases_by_discid(this_disc.id,includes=['artists', 'recordings'])

if release.get('disc'):
    this_release=release['disc']['release-list'][0]
    title = this_release['title']
    artist = this_release['artist-credit'][0]['artist']['name']
 
    with open('mdtitle.lst', 'w') as f:
        sys.stdout = f

        print('disc_title={}'.format(title))
        print('disc_performer={}'.format(artist))
        print('disc_year={}'.format(this_release['date'].split('-')[0]))
        for medium in this_release['medium-list']:
            for disc in medium['disc-list']:
                if disc['id'] == this_disc.id:
                    tracks=medium['track-list']
                    for track in tracks:
                        print('track_title{}={}'.format(track['number'], track['recording']['title']))
                        print('track_performer{}={}'.format(track['number'], format(artist)))
                    break

