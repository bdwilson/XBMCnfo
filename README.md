XBMCnfo
=======

Perl-based XBMC nfo Creator and Image Grabber

Requirements
------------
IMDB::Film;
HTML::Template;
Date::Manip;
LWP::Simple;
XML::TreePP;
File::Find;
File::Basename;
File::stat;
Getopt::Long;


I recommend installing [cpanminus](https://github.com/miyagawa/cpanminus) and installing them that way. 
<pre>
sudo apt-get install curl
curl -L http://cpanmin.us | perl - --sudo App::cpanminus
</pre>	

Then install the modules..
<pre>
sudo cpanm IMDB::Film HTML::Template Date::Manip LWP::Simple XML::TreePP File::Find \
    File::Basename File::stat Getopt::Long 
</pre>

Usage
-----
This script can be used to automate creation of .nfo files and thumbnail images or can be used
interactively.  Below are some examples of it's usage, or you can run XBMCnfo.pl 
by itself and try to figure this out on your own.

<pre>
$ XBMCnfo.pl
usage: XBMCnfo.pl [-movie|-tvshow] [-altimg] [-duration] [-overwrite] [-usedir] [-usefirst] path-to-search-for-files
    -altimg       try to get a larger image via google images

    -deldup       remove earlier (duplicate) versions of a file

    -duration     normally leaves the duration string as 0 so that ATVFiles
                  will compute this itself.  using this will grab duration 
                  from IMDB (only applies to movies)

    -overwrite    will overwrite existing .xml files (you will have the
                  option to skip files you don't want to overwrite).

    -usedir       will use the parent directory name instead of the filename
                  to classify the file (only applies to movies).

    -usefirst     will use the first match (#0) returned from the search
                  and assume that we have a successful match.  Useful
                  for unattended running.  Your names must be accurate
                  for this option to be useful.

    -searchterm   If you know the show name or IMDB/TVDB ID you want to search for, use this
                  in combination of -usefirst to force the proper show/movie name.

  -tvshow|-movie  lookup either via TheTVDB or IMDB (-movie is default if
                  nothing is specified).
</pre>

Examples
--------

### Movies

The following traverse your /media/Movies/Christmas Vacation (1989) folder, and
prompt you to confirm the name from any search matches. It will use the base directory of the Movie as the search term
for searching, overwrite any existing .nfo/.jpg files and pull larger images
from The Movie Poster database.

<pre>$ XBMCnfo.pl -duration -altimg -overwrite -usedir -movie "/media/Movies/Christmas Vacation (1989)"
FILE: /media/Movies/Christmas Vacation (1989)/xmasvacation.avi
Using Dir Christmas Vacation (1989)
Searching IMDB for: christmas vacation 
0. Christmas Vacation (1989)
N. enter a new search term
S. Skip this title
Got 1 results; use? [0]: 0
Creating /media/Movies/Christmas Vacation (1989)/xmasvacation.nfo
Writing folder.jpg to /media/Movies/Christmas Vacation (1989)/
Got new image via MoviePosterDB:
http://www.movieposterdb.com/posters/06_02/1989/0097958/l_91473_0097958_623cbd0d.jpg
</pre>

If you're confident that your directory name is going to come up with the
proper name, then you can try using -usefirst option which will not prompt and
use the first search result.

<pre>$ XBMCnfo.pl -duration -altimg -overwrite -usedir -movie -usefirst "/media/Movies/Christmas Vacation (1989)"
FILE: /media/Movies/Christmas Vacation (1989)/xmasvacation.avi
Found xmasvacation.nfo.. Will overwrite.
Using Dir Christmas Vacation (1989)
Searching IMDB for: christmas vacation 
Using first search result: Christmas Vacation (1989)
Creating /media/Movies/Christmas Vacation (1989)/xmasvacation.nfo
Writing folder.jpg to /media/Movies/Christmas Vacation (1989)/
Got new image via MoviePosterDB: http://www.movieposterdb.com/posters/06_02/1989/0097958/l_91473_0097958_623cbd0d.jpg
</pre>


### TV Shows

The following will scan "/media/TV/New Girl" for media files formatted with
the show name in the file title and Season/Episode info in the standard SXXEXX
format. It will use the first search result and will not overwrite files. This
will also write a tvshow.nfo file to the base "New Girl" directory.

<pre>$ XBMCnfo.pl -tvshow -usefirst "/media/TV/New Girl"
FILE: /tmp/New Girl/Season 2/New Girl - S02E01 - Re-Launch.mkv
Searching TheTVDB for: New Girl (Season 2, Episode 1)
http://www.thetvdb.com/api/GetSeries.php?seriesname=New Girl
Using first search result: New Girl
TheTVDB Series: http://www.thetvdb.com/api/7638ED60CC19B062/series/248682/en.xml
TheTVDB Series ZIP: http://www.thetvdb.com/api/7638ED60CC19B062/series/248682/all/en.zip
TheTVDB: http://www.thetvdb.com/api/7638ED60CC19B062/series/248682/default/2/1/en.xml
Creating /media/TV/New Girl/Season 2/New Girl - S02E01 - Re-Launch.nfo
Creating /media/TV/New Girl/tvshow.nfo
Writing folder.jpg to /media/TV/New Girl/Season 2/
Writing another folder.jpg to /media/TV/New Girl/folder.jpg
</pre>

Or if you know the TVDB ID or want to pass a search term to use...

<pre>$ XBMCnfo.pl -tvshow -usefirst -overwrite -searchterm 248682 /media/TV/New\ Girl
FILE: /media/TV/New Girl/Season 2/New Girl - S02E01 - Re-Launch.mkv
Searching TheTVDB for: New Girl (Season 2, Episode 1)
TheTVDB Series: http://www.thetvdb.com/api/7638ED60CC19B062/series/248682/en.xml
TheTVDB Series ZIP: http://www.thetvdb.com/api/7638ED60CC19B062/series/248682/all/en.zip
TheTVDB: http://www.thetvdb.com/api/7638ED60CC19B062/series/248682/default/2/1/en.xml
Creating /media/TV/New Girl/Season 2/New Girl - S02E01 - Re-Launch.nfo
Creating /media/TV/New Girl/tvshow.nfo
Writing folder.jpg to /media/TV/New Girl/Season 2/
Writing another folder.jpg to /media/TV/New Girl/folder.jpg
</pre>

Bugs/Contact Info
-----------------
Bug me on Twitter at [@brianwilson](http://twitter.com/brianwilson) or email me [here](http://cronological.com/comment.php?ref=bubba).


