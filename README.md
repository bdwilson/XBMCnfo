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
prompt you to confirm the name if the number of matches is > 1. It will use the base directory of the Movie as the search term
for searching, overwrite any existing .nfo/.jpg files and pull larger images from The Movie Poster database.

<pre>$ XBMCnfo.pl -duration -altimg -overwrite -usedir -movie "/media/Movies/Christmas Vacation (1989)"
FILE: /media/Movies/Christmas Vacation (1989)/xmasvacation.avi
Found xmasvacation.nfo.. Will overwrite.
Using Dir Christmas Vacation (1989)
Searching IMDB for: christmas vacation 
Using first search result: Christmas Vacation (1989)
Creating /media/Movies/Christmas Vacation (1989)/xmasvacation.nfo
Saving http://ia.media-imdb.com/images/M/MV5BMTI1OTExNTU4NF5BMl5BanBnXkFtZTcwMzIwMzQyMQ@@._V1_SY317_CR5,0,214,317_.jpg to /media/Movies/Christmas Vacation (1989)/folder.jpg
Got new image via MoviePosterDB: http://www.movieposterdb.com/posters/06_02/1989/0097958/l_91473_0097958_623cbd0d.jpg
</pre>

Here's an example withg multiple results where user interaction is required:

<pre>$ XBMCnfo.pl -duration -altimg -overwrite -usedir -movie /media/Movies/Duplicity
FILE: /media/Movies/Duplicity/Duplicity.mp4
Found Duplicity.nfo.. Will overwrite.
Using Dir Duplicity
Searching IMDB for: duplicity
14. Smallville (2001) (TV Series)
13. Duplicity (2002) (TV Episode) -
12. Army Wives (2007) (TV Series)
11. Duplicity (2008) (TV Episode) -
10. Cinetipp (2002) (TV Series)
 9. Duplicity (2009) (TV Episode) -
 8. Revenge (2011) (TV Series)
 7. Duplicity (2011) (TV Episode) -
 6. Duplicity (2007) (Short)
 5. Duplicity (1978) (Short)
 4. Duplicity (1916) (Short)
 3. Duplicity (2011)
 2. Duplicity (2004)
 1. Trouble (2005) aka "Duplicity"
 0. Duplicity (2009)
 N. enter a new search term
 S. Skip this title
Got 15 results; use? [0]: 0
Creating /media/Movies/Duplicity/Duplicity.nfo
Saving http://ia.media-imdb.com/images/M/MV5BMjE2MTg2MzU2NF5BMl5BanBnXkFtZTcwMTMyNjkxMg@@._V1_SY317_CR0,0,214,317_.jpg to /media/Movies/Duplicity/folder.jpg
Got new image via MoviePosterDB: http://www.movieposterdb.com/posters/09_03/2009/1135487/l_1135487_e6df4ae1.jpg
</pre>

If you're confident that your directory name is going to come up with the
proper search result, then you can try using -usefirst option which will not prompt and
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

Or if you know the TVDB ID or want to pass a search term instead of relying on the file name.

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


