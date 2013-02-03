#!/usr/bin/perl -w
# 
#  XBMCnfo Generator and Image grabber
#  bubba@bubba.org
#
#  This originally started as a xml generator for ATVfiles back in
#  2009, but since I've moved on to XBMC, so has this script.  Let 
#  me know if you find anything that is broken; patches welcome of 
#  course. Please see: http://github.com/bdwilson/XBMCnfo for more
#  info.
#
#  v1.0 

use strict;
use IMDB::Film;
use HTML::Template;
use Date::Manip;
use File::Basename;
use File::stat;
use Fcntl;
use utf8;
use Getopt::Long;
use LWP::Simple;
use XML::TreePP;
use File::Find;
use Data::Dumper;
 
# put file extensions in here you want to look for.  
# make sure to escape your "." and put a | in betweeen
# your extensions
my $extensions = qw'\.avi|\.wmv|\.mp4|\.mkv';
 
# if image size is less than this many bytes,
# try getting a large image from google images
# (requires -altimg option to even try this)
my $filesize = "30000";

# If you know of TV show / Movie names you want to always
# map to a particular name, then use this to map them properly.
# "Your Dir/File Name" => "IMDB/TVDB Database Name" is the format.
my %fixup = ("The Office" => "The Office (US)",
	     "Human Target" => "Human Target (2010)",
	     "Thomas & Friends" => "Thomas the Tank",
             "Castle" => "Castle (2009)");
 
########## You shouldn't have to edit below here #########
my ($template_ref, $dir, $searchTerm, $imdb, $overwrite, $usedir, $xml, $cover,
$content, $usefirst, $tvshow, $movie, $season, $episode, $show, $show_name,
$episode_num, %season_hash, $altimg, $deldup, $xbmc_template_ref, $xbmcxml,
$xbmc_tvseries_template_ref, $series, $xbmcseriesxml, $forcesearch);
 
my $use_duration = 0;
&usage unless GetOptions("duration" => \$use_duration, "overwrite" =>
\$overwrite, "usedir" => \$usedir, "usefirst" => \$usefirst,
"movie" => \$movie, "tvshow" => \$tvshow, "altimg"=> \$altimg, "deldup"=>
\$deldup, "searchterm=s" => \$forcesearch);

# do movie searches by default
if (!$tvshow)  {
	$movie = 1;
}
 
# now required for TVDB calls.
my $tvdb_key = "7638ED60CC19B062";

# autoflush;
$|=1;
# unicode support
binmode(STDOUT, ":utf8");
 
&usage unless $ARGV[0];
 
# define the output template here
my $movie_template =<<MXML;
<movie>
   <title><TMPL_VAR NAME=TITLE></title>
   <plot><TMPL_VAR NAME=PLOT></plot>
   <id>tt<TMPL_VAR NAME=ID></id>
   <mpaa><TMPL_VAR NAME=CERTIFICATION></mpaa>
   <rating><TMPL_VAR NAME=RATING></rating>
   <year><TMPL_VAR NAME=DATE></year>
   <runtime><TMPL_VAR NAME=DURATION></runtime>
   <TMPL_LOOP NAME=GENRE><TMPL_VAR NAME=NAME></TMPL_LOOP>
   <TMPL_LOOP NAME=CAST><TMPL_VAR NAME=NAME></TMPL_LOOP>
   <TMPL_LOOP NAME=DIRECTORS><TMPL_VAR NAME=NAME></TMPL_LOOP>
</movie>
MXML
 
my $xbmc_tv_template=<<XTVXML;
<episodedetails xsd="http://www.w3.org/2001/XMLSchema" xsi="http://www.w3.org/2001/XMLSchema-instance">
   <title><TMPL_VAR NAME=TITLE></title>
   <season><TMPL_VAR NAME=SEASON></season>
   <episode><TMPL_VAR NAME=EPISODENUM></episode>
   <plot><TMPL_VAR NAME=DESCRIPTION></plot>
   <thumb><TMPL_VAR NAME=THUMB></thumb>
   <rating><TMPL_VAR NAME=RATING></rating>
   <aired><TMPL_VAR NAME=DATE></aired>
</episodedetails>
XTVXML

my $xbmc_tvseries_template=<<XTVSXML;
<tvshow xsd="http://www.w3.org/2001/XMLSchema" xsi="http://www.w3.org/2001/XMLSchema-instance">
   <title><TMPL_VAR NAME=TITLE></title>
   <episodeguideurl><TMPL_VAR NAME=EPISODEGUIDE></episodeguideurl>
   <episodeguide>
      <url><TMPL_VAR NAME=EPISODEGUIDE></url>
   </episodeguide>
   <studio><TMPL_VAR NAME=NETWORK></studio>
   <mpaa><TMPL_VAR NAME=MPAA></mpaa>
   <rating><TMPL_VAR NAME=RATING></rating>
   <thumb><TMPL_VAR NAME=THUMB></thumb>
   <id><TMPL_VAR NAME=ID></id>
   <plot><TMPL_VAR NAME=DESCRIPTION></plot>
   <TMPL_LOOP NAME=GENRE><TMPL_VAR NAME=NAME></TMPL_LOOP>
   <premiered><TMPL_VAR NAME=DATE></premiered>
</tvshow>
XTVSXML
 
find(\&findfiles,$ARGV[0]);
 
sub findfiles {                       
  my $file = $File::Find::name;      
 
  undef $template_ref;
  if ($movie) {
  	$template_ref = \$movie_template;
  } elsif ($tvshow) {
  	$xbmc_template_ref = \$xbmc_tv_template;
  	$xbmc_tvseries_template_ref = \$xbmc_tvseries_template;
  }
  return unless -f $file;            
  return unless $_ =~ m/$extensions/io;  
  return if $_ =~ /sample/i;
  print "FILE: $file\n";
  if ($deldup) {
  	my $dup_file = $file;
  	$dup_file =~ s/\.1\.(\S{1,3})$/\.$1/;
  	if (($file =~ /\.1\.\S{1,3}$/) && (-f $dup_file)) {
		print "Removing previous verison of file: $dup_file\n";
		unlink "$dup_file";
	}
  } 
 
   $dir = dirname($file);
   $dir =~ s/.*\///;
 
   my ($xmlfile,$xmlpath,$xmlfilesuffix) = fileparse($file,qr/\.[^.]*/);
 
   $xmlfile .= ".nfo" ;
   if (-f "$xmlpath/$xmlfile" && (!$overwrite)) { 
	return;
   } elsif (-f "$xmlpath/$xmlfile") {
	print "Found $xmlfile.. Will overwrite.\n";
   }
 
 
# now we start.
# derive search term from filename
$searchTerm = guessTitleFromFilename($file);

foreach my $fix (keys %fixup) {
	if ($searchTerm =~ /$fix/) {
		$searchTerm=$fixup{$fix};
		print "Found a fixed name: $fix => $searchTerm\n";
	}
}

$show_name = $searchTerm;
if ($forcesearch) {
	$searchTerm = $forcesearch;
	print "Overriding Search Term with: $searchTerm\n";
}
 
undef $imdb;
undef $show;
 
# main loop
if ($movie) {
 while ($imdb = IMDB::Film->new(crit => "$searchTerm")) {
  my @results = @{ $imdb->matched };
  if (!@results && $imdb) {
	#print Dumper $imdb;
	$searchTerm = $imdb->id;
  }
 
  # we'll assume the 1st hit is what we want or if we only
  # get one result, we'll use that.
  if ((@results > 0 && $usefirst) || (@results == 1)) {
	$searchTerm = $results[0]->{id};
	$show_name = $results[0]->{title};
	print "Using first search result: $show_name\n";
	last;
  } elsif ($usefirst) {
	print "No results found for $searchTerm. Try the -usedir option or removing -usefirst. Exiting.\n";
	exit;
  }
 
  if (!$usefirst) {
    my $choice = &displayMenu(@results);
    # undef and replace $imdb object
    if ($choice =~ /^[Nn]$/) {
      $searchTerm = &getSearchTerm;
      undef $imdb;
    }  elsif ($choice =~ /^[Ss]$/) {
       return;
    } else {
      $searchTerm = $results[$choice]->{id};
      $show_name = $results[$choice]->{title};
      last;
    }
  }
 }
} elsif ($tvshow && $searchTerm !~ /^\d{6,9}$/)  {
  my @results = doSeriesSearch($searchTerm);
  my $found = 0;
 
  # we'll assume the 1st hit is what we want or if we only
  # get one result, we'll use that.
  if ((@results > 0 && $usefirst) || (@results == 1)) {
        $searchTerm = $results[0]->{id};
        $show_name = $results[0]->{title};
        print "Using first search result: $show_name\n";
        $found++;
  } elsif ($usefirst) {
	print "No results found for $searchTerm.  Try removing -usefirst. Exiting\n";
	exit;
  }
  if (!$usefirst && !$found) {
    my $choice = &displayMenu(@results);
    if ($choice =~ /^[Nn]$/) {
      $searchTerm = &getSearchTerm;
    }  elsif ($choice =~ /^[Ss]$/) {
       return;
    } else {
      $searchTerm = $results[$choice]->{id};
      $show_name = $results[$choice]->{title};
    }
  }
}
 
# we got a single result here (possibly by searching on id)
 
undef $xml;
 
if ($movie) { 
	print Dumper $imdb;
	$xml = imdbToTmpl($imdb);
	#print Dumper $xml;
	$cover = $imdb->cover();
	my ($outfile,$path,$suffix) = fileparse($file,qr/\.[^.]*/);
	$outfile .= ".nfo";
	&writeXMLFile($path.$outfile, $xml);
} elsif ($tvshow) {
        $series = getSeriesInfo($searchTerm);
        $show = getEpiInfo($searchTerm,$episode,$season);
        $cover = getBanner($searchTerm,$season);
	# write out xbmc episode file
        $xbmcxml = showToXBMCTmpl($show,$cover);
	my ($outfile,$path,$suffix) = fileparse($file,qr/\.[^.]*/);
	$outfile .= ".nfo";
	&writeXMLFile($path.$outfile, $xbmcxml);

	# write out xbmc series file
	$xbmcseriesxml = seriesToXBMCTmpl($series,$cover);
	($outfile,$path,$suffix) = fileparse($file,qr/\.[^.]*/);
	$outfile = "tvshow.nfo";
	$path =~ s/.[^\/]*\/$/\//;
	#print "$path | $outfile\n";
	&writeXMLFile($path.$outfile, $xbmcseriesxml);
}
 

my ($coverfile,$coverfilepath,$coverfilesuffix) = fileparse($file,qr/\.[^.]*/); 
#$coverfile .= ".jpg" ; this was for ATVFiles I believe...

$content = get($cover);
if ((! -f "$coverfilepath/folder.jpg") || ($overwrite)) { 
	print "Saving $cover to $coverfilepath" . "folder.jpg\n";
	open(OUT, ">$coverfilepath/folder.jpg");
	print OUT $content;
	close(OUT);
}
my $fpath = $coverfilepath;
$fpath =~ s/.[^\/]*\/$/\//;
$fpath = $fpath . "folder.jpg";
if (((! -f "$fpath") || ($overwrite)) && (!$movie) && ($coverfilepath =~ /Season/)) {
	print "Writing another folder.jpg to $fpath\n";
	open(OUT, ">$fpath");
	print OUT $content;

}
 
my $fsize=stat("$coverfilepath/folder.jpg")->size;
if (($fsize < $filesize) && ($altimg) && ($movie)) {
	# use movieposterdb for movies since IMDB is so low res
	my $search = "http://www.movieposterdb.com/search?type=movies&query=$searchTerm";
	my $content = get($search);
	my $id = $searchTerm;
	$id =~ s/^0//g;
	if ($content =~ m{img\ssrc="(http://www.movieposterdb.com/posters/[\/\S+\_]+/0?$id/\S+$id\_\S+.jpg)" }) {
		my $match = $1;
                $match =~ s/$id\/s_/$id\/l_/g;  
                $match =~ s/$id\/m_/$id\/l_/g;  
		if ($content = get($match)) {
                	print "Got new image via MoviePosterDB: $match\n";
			if (open(OUT, ">$coverfilepath/folder.jpg")) {
        			print OUT $content ;
        			close(OUT) ;
			}
		}
	}
}
}
exit 0;
 
sub writeXMLFile {
  my $outfile = shift;
  my $xml = shift;
 
  if (open(OUT, ">$outfile")) {
    binmode(OUT, ":utf8");
    print "Creating $outfile\n";
    print OUT $xml;
    close(OUT);
  } else {
    print "Failed to create $outfile\n";
    return undef;
  }
  return 1;
}
 
sub getSearchTerm {
  print "Enter new search term or IMDB/TV id: ";
 
  my $term = <STDIN>;
  chomp($term);
  return $term;
}
 
sub displayMenu {
  my @results = @_;
  # present options
  my $i = $#results;
  my $maxpad = length($i);
  my $pad;
  my $cnt = 0;
 
 if ($movie) {
  foreach my $result (reverse @{ $imdb->matched }) {
    if ($result->{title} =~ /\S+/) {
    	my $length = length("$i");
    	$pad = $length >= $maxpad ? 0 : $maxpad - $length;
    	print ' ' x $pad;
    	print "$i. ".$result->{title}."\n";
    	$i--;
	$cnt++;
    } 
  }
 } elsif ($tvshow) {
  foreach my $result (reverse @results) {
    if ($result->{title} =~ /\S+/) {
    	my $length = length("$i");
    	$pad = $length >= $maxpad ? 0 : $maxpad - $length;
    	print ' ' x $pad;
    	print "$i. ".$result->{title}."\n";
    	$i--;
	$cnt++;
    }
  }
 }
 
  $pad = $maxpad - 1;
  print ' ' x $pad;
  print "N. enter a new search term\n";
  print ' ' x $pad;
  print "S. Skip this title\n";

  my $choice;
  if ($cnt == 0) { 
  	print "Got $cnt results; use? [N]: ";
  	$choice = <STDIN>;
  	chomp($choice);
  	$choice = "N" if ($choice =~ m/^\s*$/);
  } else {
  	print "Got $cnt results; use? [0]: ";
  	$choice = <STDIN>;
  	chomp($choice);
  	$choice = "0" if ($choice =~ m/^\s*$/);
  }
  return $choice;
}
 
sub seriesToXBMCTmpl {
  my $show = shift;
  my $cover = shift;
  my $t;
  my $tmpl = HTML::Template->new(
	scalarref => $xbmc_tvseries_template_ref,
	die_on_bad_params => 0,
  );
  $tmpl->param(TITLE => $show->{'Name'});
  $tmpl->param(DESCRIPTION=> $show->{'Overview'});
  $tmpl->param(DATE => $show->{'FirstAired'});
  $tmpl->param(MPAA=> $show->{'MPAA'});
  $tmpl->param(Rating=> $show->{'Rating'});
  $tmpl->param(NETWORK => $show->{'Network'});
  $tmpl->param(EPISODEGUIDE => $show->{'EpisodeGuide'});
  $tmpl->param(ID=> $show->{'id'});
  $tmpl->param(THUMB=> $cover);
  my @genres = ();
  foreach my $genre (split(/\|/,$show->{'Genre'})) {
    if ($genre =~ /\S+/) {
    	my %genre_row;
    	$genre_row{NAME} = "<genre>$genre</genre>\n";
    	push(@genres, \%genre_row);
     }
  }
  $tmpl->param(GENRE => \@genres);
  return $tmpl->output;
}

sub showToXBMCTmpl {
  my $show = shift;
  my $cover = shift;
  my $t;
  my $tmpl = HTML::Template->new(
	scalarref => $xbmc_template_ref,
	die_on_bad_params => 0,
  );
  $t = $show->{'Name'};
  $tmpl->param(TITLE => $t);
  $tmpl->param(SUMMARY => $show->{'Name'});
  $tmpl->param(DESCRIPTION=> $show->{'Overview'});
  my $date = ParseDate($show->{'FirstAired'});
  $date = UnixDate("$date","%Y-%m-%d");
  $tmpl->param(DATE => "$date");
  $tmpl->param(EPISODE => $episode);
  $tmpl->param(SEASON => $season);
  $tmpl->param(NAME => $show_name);
  $tmpl->param(RATING => $show->{'Rating'});
  $tmpl->param(THUMB => $cover);
  #$tmpl->param(ARTIST=> $show_name);
  $tmpl->param(EPISODENUM=> $episode);
  return $tmpl->output;
}

sub imdbToTmpl {
  my $film = shift;
  my $tmpl = HTML::Template->new(
        scalarref => $template_ref,
        die_on_bad_params => 0,
    );
 
  $tmpl->param(TITLE => $film->title());
  $tmpl->param(PLOT => $film->plot());
  if ($film->plot()) {
  	$tmpl->param(PLOT => $film->plot());
  } else {
  	$tmpl->param(PLOT => $film->storyline());
  }

  $tmpl->param(ID => $film->id());
 
  if ($use_duration) {
    my $duration = $film->duration();
    if ($duration =~ /(\d+)/) {
		$duration = $1;
    } else {
		$duration = 0;
    }
    $tmpl->param(DURATION => $duration);
  } else {
    $tmpl->param(DURATION => 0);
  }
 
  if ($film->mpaa_info()) {
  	$tmpl->param(CERTIFICATION => $film->mpaa_info());
  } else {

  	my $cert = $film->certifications();
  	for my $country (keys %$cert) {
		if ($country =~ /US/) {
			$tmpl->param(CERTIFICATION => $cert->{$country});
		}
  	}
  }
 
  my $rating = $film->rating();
  $tmpl->param(RATING => $rating);
 
  # find earliest release date
  my $dates;
  if (defined($film->release_dates())) {
    foreach my $day (@{ $film->release_dates()}) {
      if(my $date = ParseDate($day->{date})) {
        #$date = UnixDate("$date","%s");
        $dates->{$date} = $day->{country};
      }
    }
  }
  foreach my $utc (sort keys %$dates) {
    my $date = ParseDate($utc);
    $date = UnixDate("$date","%Y");
    $tmpl->param(DATE => "$date");
    last;
  }
 
  # genres
  my @genres = ();
  foreach my $genre (@{ $film->genres() }) {
    my %genre_row;
    $genre_row{NAME} = "<genre>$genre</genre>\n";
    push(@genres, \%genre_row);
  }
  $tmpl->param(GENRE => \@genres);
 
  # cast
  my @cast = ();
  foreach my $castmember (@{ $film->cast() }) {
    chomp($castmember->{name});
    my %cast_row;
    $cast_row{NAME} = "<actor>$castmember->{name}</actor>\n";
    push(@cast, \%cast_row);
  }
  @cast = @cast[0..4];
  $tmpl->param(CAST => \@cast);
 
  # producers
  my @directors = ();
  foreach my $director (@{ $film->directors() }) {
    my %director_row;
    $director_row{NAME} = "<director>$director->{name}</director>\n";
    push(@directors, \%director_row);
  }
  @directors = @directors[0..1] if $#directors > 0;
  $tmpl->param(DIRECTORS => \@directors);
 
  return $tmpl->output;
}
 
sub guessTitleFromFilename {
  my $file = shift;
  $season = "";
  $episode = "";
  my $guess = fileparse($file);
  if ($usedir && $movie) {
	$guess = $dir;
	print "Using Dir $dir\n";
  }
  if ($tvshow) {
	# Expecting something like Show - SXXEXX - Title
	# Show - Title - SXXEXX, or something without the spaces.
  	$guess =~ s/\(.*\)//g; # remove anything in ()s
	$guess =~ /(.*?)[\.\s\-]+[Ss]?(\d{1,2})[Eex]?(\d{1,3})/;
	if (!$2 && !$3) {
		$guess =~ /(.*?)[\s\-\.\[]+([0-9]+)x([0-9]+)]?/;
		$guess = $1; 
		$season = $2;
		$episode = $3;
	} else {
		$guess = $1; 
		$season = $2;
		$episode = $3;
	}
	my $season_tmp = $season . $episode;
	if (length($season_tmp) < 4) { # when episodes are #'erd like 101
		$season_tmp =~ /(\d)(\d{1,3})/;
		$season = $1;
		$episode = $2;
	}
	$guess =~ s/\./ /g;  # some shows have .'s instead of spaces
	$guess =~ s/\-[^-]*$//g; # remove everything after last "-" (show name) 
	$episode =~ s/^0//;
	$season =~ s/^0//;
	print "Searching TheTVDB for: $guess (Season $season, Episode $episode)\n";
  } elsif ($movie) {
  	$guess =~ s/\..{1,3}\.?.{0,3}$//;   # strip off extension or sabnzbd 
		             		    # duplicate file/dir extension (.#)
  	$guess =~ s/\(.*\)//g; # remove anything in ()s
  	$guess =~ s/\[.*\]//g; # remove anything in []s
  	$guess =~ s/[\.|\'|\"|\,]//g;  # remove .,"'
  	$guess =~ tr/A-Z/a-z/; # eh
  	$guess =~ s/_/ /g;
  	$guess =~ s/-\d+$//;
	print "Searching IMDB for: $guess\n";
 }
 
  return $guess;
}
 
sub getEpiID {
        # returns episodeID for a given series, season, episode.  
        my ($s,$e,$se) = @_;
        my $episode_url = "http://www.thetvdb.com/interfaces/GetEpisodes.php?seriesid=$s&episode=$e&season=$se";
        my $content = get ($episode_url);
        my $xs = XML::TreePP->new();
        my $ref = $xs->parse($content);
 
        foreach my $key (@{$ref->{Items}->{Item}}) {
                if ($key->{'id'}) {
                        return $key->{'id'};
                }
        }
}
 
sub doSeriesSearch {
        # returns an array of hashes with search results (name & ID)
        my $term = shift;
        my $series_url = "http://www.thetvdb.com/api/GetSeries.php?seriesname=$term";
	print "Performing TheTVDB Search: $series_url\n";
        my $content = get ($series_url);
        my $xs = XML::TreePP->new();
        my $ref = $xs->parse($content);
        my @array;
        my $count = 0;

        # more than 1 result, we get an array, otherwise, we get a hash
        if (ref($ref->{Data}->{Series}) eq 'ARRAY') {
                foreach my $key (@{$ref->{Data}->{Series}}) {
                        $array[$count]->{id}=$key->{'seriesid'};
                        $array[$count]->{title}=$key->{'SeriesName'};
                        $count++;
                }
        } else {
                $array[$count]->{id}=$ref->{Data}->{Series}->{'seriesid'};
                $array[$count]->{title}=$ref->{Data}->{Series}->{'SeriesName'};
        }
        return @array;
}

sub getSeriesInfo {
        # returns hash with series info.
        my ($s) = @_;
	my $series_url = "http://www.thetvdb.com/api/$tvdb_key/series/$s/en.xml";
        my $series_zip = "http://www.thetvdb.com/api/$tvdb_key/series/$s/all/en.zip";
        #my $episode_url = "http://www.thetvdb.com/interfaces/GetEpisodes.php?seriesid=$s&episode=$e&season=$se";       
        print "TheTVDB Series: $series_url\n";
        print "TheTVDB Series ZIP: $series_zip\n";
        my $content = get ($series_url);
        my $xs = XML::TreePP->new();
        my $ref = $xs->parse($content);
        my %info;

        # going to assume we always get 1 result back, otherwise we kill a kitten
	#print Dumper $ref;
        if ($ref->{Data}->{Series}->{'id'}) {
		if ($ref->{Data}->{Series}->{'FirstAired'} !~ /^HASH/) {
                	$info{'FirstAired'} = $ref->{Data}->{Series}->{'FirstAired'};
		} else {
                	$info{'FirstAired'} = "now";
		}
		if ($ref->{Data}->{Series}->{'Rating'} !~ /^HASH/) {
			$info{'Rating'} = $ref->{Data}->{Series}->{'Rating'};
		} else {
			$info{'Rating'} = "Unknown";
		}
		if ($ref->{Data}->{Series}->{'Overview'} !~ /^HASH/) {
			$info{'Overview'} = $ref->{Data}->{Series}->{'Overview'};
		} else {
			$info{'Overview'} = "Unknown";
		}
		if ($ref->{Data}->{Series}->{'SeriesName'} !~ /^HASH/) {
			$info{'Name'} = $ref->{Data}->{Series}->{'SeriesName'};
		} else {
			$info{'Name'} = "Unknown";
		}
		if ($ref->{Data}->{Series}->{'Genre'} !~ /^HASH/) {
			$info{'Genre'} = $ref->{Data}->{Series}->{'Genre'};
		} else {
			$info{'Genre'} = "Unknown";
		}
		if ($ref->{Data}->{Series}->{'Network'} !~ /^HASH/) {
			$info{'Network'} = $ref->{Data}->{Series}->{'Network'};
		} else {
			$info{'Network'} = "Unknown";
		}
		if ($ref->{Data}->{Series}->{'ContentRating'} !~ /^HASH/) {
			$info{'MPAA'} = $ref->{Data}->{Series}->{'ContentRating'};
		} else {
			$info{'MPAA'} = "Unknown";
		}
		$info{'EpisodeGuide'} = $series_zip;
		$info{'id'} = $s;
        }
        return \%info;
}
sub getEpiInfo {
        # returns hash with episode info.
        my ($s,$e,$se) = @_;
        my $episode_url = "http://www.thetvdb.com/api/$tvdb_key/series/$s/default/$se/$e/en.xml";
        #my $episode_url = "http://www.thetvdb.com/interfaces/GetEpisodes.php?seriesid=$s&episode=$e&season=$se";       
        print "TheTVDB: $episode_url\n";
        my $content = get ($episode_url);
        my $xs = XML::TreePP->new();
        my $ref = $xs->parse($content);
        my %info;

        # going to assume we always get 1 result back, otherwise we kill a kitten
	#print Dumper $ref;
        if ($ref->{Data}->{Episode}->{'id'}) {
		if ($ref->{Data}->{Episode}->{'FirstAired'} !~ /^HASH/) {
                	$info{'FirstAired'} = $ref->{Data}->{Episode}->{'FirstAired'};
		} else {
                	$info{'FirstAired'} = "now";
		}
		if ($ref->{Data}->{Episode}->{'Overview'} !~ /^HASH/) {
			$info{'Overview'} = $ref->{Data}->{Episode}->{'Overview'};
		} else {
			$info{'Overview'} = "Unknown";
		}
		if ($ref->{Data}->{Episode}->{'EpisodeName'} !~ /^HASH/) {
			$info{'Name'} = $ref->{Data}->{Episode}->{'EpisodeName'};
		} else {
			$info{'Name'} = "Unknown";
		}
		if ($ref->{Data}->{Episode}->{'Rating'} !~ /^HASH/) {
			$info{'Rating'} = $ref->{Data}->{Episode}->{'Rating'};
		} else {
			$info{'Rating'} = "Unknown";
		}
        }
        return \%info;
}

sub getBanner {
        # returns the url of a season-specific series image (if possible), otherwise, the most 
        # recent series image.  
        my ($seriesid,$season) = @_;
        my $banner_url = "http://www.thetvdb.com/api/$tvdb_key/series/$seriesid/banners.xml";
        my $banner_loc = "http://www.thetvdb.com/banners";
        my $content = get ($banner_url);
        my $xs = XML::TreePP->new();
        my $ref = $xs->parse($content);
        my $season_tmp;
        my %valid_banners = ();
	
        foreach my $key (@{$ref->{Banners}->{Banner}}) {
                if ($key->{'BannerType'} eq "season" && 
			 $key->{'BannerType2'} ne "seasonwide") {
                        $season_tmp = $key->{'Season'};
                        if ($season_tmp =~ /\d+/) {
                                if ($season eq $season_tmp) {
                                        # we found a season-specific image
                                        return "$banner_loc/$key->{'BannerPath'}";
                                } else {
				#	print "Type: " . $key->{'BannerType'} .  " Season: " . $key->{'Season'} .  " URL: $banner_loc/" . $key->{'BannerPath'} . "\n";
                                        $valid_banners{$season_tmp}="$banner_loc/$key->{'BannerPath'}"
                                }
                        }
                }
        }

        foreach my $b (reverse sort keys %valid_banners) {
                # otherwise, we return the most recent season-specific image
		#print " B: $b : selecing $valid_banners{$b}\n";
                return "$valid_banners{$b}";
        }
}
 
sub usage {
  my $name = fileparse($0);
  print "usage: $name [-movie|-tvshow] [-altimg] [-duration] [-overwrite] [-usedir] [-usefirst] path-to-search-for-files\n";
  print "    -altimg       try to get a larger image via google images\n\n"; 
  print "    -deldup       remove earlier (duplicate) versions of a file\n\n";
  print "    -duration     normally leaves the duration string as 0 so that ATVFiles\n";
  print "                  will compute this itself.  using this will grab duration \n";
  print "                  from IMDB (only applies to movies)\n\n";
  print "    -overwrite    will overwrite existing .xml files (you will have the\n"; 
  print "                  option to skip files you don't want to overwrite).\n\n";
  print "    -usedir       will use the parent directory name instead of the filename\n";
  print "                  to classify the file (only applies to movies).\n\n";
  print "    -usefirst     will use the first match (#0) returned from the search\n";
  print "                  and assume that we have a successful match.  Useful\n";
  print "                  for unattended running.  Your names must be accurate\n";
  print "                  for this option to be useful.\n\n";
  print "    -searchterm   If you know the show name or IMDB/TVDB ID you want to search for, use this\n";
  print "                  in combination of -usefirst to force the proper show/movie name.\n\n";
  print "  -tvshow|-movie  lookup either via TheTVDB or IMDB (-movie is default if\n";
  print "                  nothing is specified).";
  print "\n";
  print "\n";
  exit 1;
}
 
 
1;
