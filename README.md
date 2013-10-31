README file for ShowdyPi

ShowdyPi is a one file solution for automating TV show downloads for users with an NewzNab account using NZBget (and soon Sabnzbd).

There are plenty of auto show downloaders at the moment. Most of them are far superior to this script. The main reason for this script is for running on very old, embedded, headless (or other) environments. For example, satellite receivers, phones, very old PCs, STB etc. It is completely command line driven and requires little configuration and/or dependencies*

What does it do?

ShowdyPi will get your TV shows for you. The workflow is like this:
Configure ShowdyPi with your NewzNab details (URL, API key) and NZBGet deatail (IP, port, API key)
Use the command line interface to search and add shows to your ShowdyPi database.
ShowdyPi will then connect to the internet (Trakt.tv via API) and pull down season/episode information for your shows.
Configure each show, indicating which shows you have already seen and which are outstanding.
ShowdyPi will then (when run manually or launched on a schedule) read the local database for unseen shows, connect to Trakt.tv, get the latest show available and send this request to your NewzNab server.
If available on you NewzNab server ShowdyPi will then select the best files size (based on your preferences)and send that file to your NZBGet application for download.

Once you're configured add ShowdyPi to your crontab and forget about it, it'll do the rest.


Install details.

Dependencies: perl use JSON::XS; IO::Socket::SSL, LWP::UserAgent, XML::Simple, DBI, Frontier::Client

For Debian / Ubuntu install from packages

sudo apt-get install libjson-xs-perl \
libio-socket-ssl-perl 
libwww-perl \
libxml-simple-perl \
libdbd-sqlite3 \
libdbd-sqlite3-perl \
libfrontier-rpc-perl \


Windows: Not tested but may work!

Usage:

To run the application e.g. to set up the config, add/remove shows, build you database etc:

perl showdypi.pl
This will present you with the interface where you can configure your setup

perl showdypi.pl --getsome
This scans your database for unwatched shows and checks to see if they're available for download. Gets them if available.

perl showdypi.pl --upgrade
This upgrades the show/season/episode database. Useful for shows still being broadcast as the episode information isn't always available in advance. For a large database this can be a little intensive. 
Recommend running this every couple of nights, when the system is idle

Both --upgrade and --getsome take a further argument of --debug. This outputs some extra information that can be useful for debugging etc.

NOTE: On first run you will be prompted to setup your API/Server config.
To run on a crontab edit the showdypi.pl file and change the $showdy_path at the top of the file to point to your base directory. 
