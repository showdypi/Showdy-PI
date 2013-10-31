#!/usr/bin/perl
# 
# Showdy Pi PVR for Usenet
# Author: showdypi@gmail.com
# Version: RC 1.00
# 31/10/2013

use strict;
use JSON::XS;
use IO::Socket::SSL qw();
use LWP::UserAgent qw();
use XML::Simple;
use DBI;
use Frontier::Client;
binmode(STDOUT, ":utf8");

# CHANGE BELOW IF RUNNING AS A CRONJOB OR SCHEDULED TASK
my $showdy_path = '/home/pi/'; 
															
															
##########################################################################################################################	
## NOTHING TO EDIT BELOW HERE																							##
##########################################################################################################################														


$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;
my $debug = 0;

my $os = $^O;
my $clear_command;
         if($os eq 'MSWin32'){$clear_command = "cls"}
         else {$clear_command = "clear"}

if (substr ($showdy_path,-1) eq '/' ) {
	chop $showdy_path;
}

my $dbh = Showdy::new_dbh();
my $config = load_config($dbh);
$config->{dbh} = $dbh;
$config->{search_url} = "$config->{trakt_search_url}$config->{trakt_api}/";
my $showdy = Showdy->new($config);

if ( $showdy->{firstrun} =="1" ) {
	$showdy->update_config
}

if ( $ARGV[0] eq '--getsome' ) {
	if ($ARGV[1] eq '--debug' ) {$debug ='1'}
	$showdy->getsome("manual");
	exit;
}

if ( $ARGV[0] eq '--upgrade' ) {
	if ($ARGV[1] eq '--debug' ) {$debug ='1'}
	$showdy->global_upgrade;
	exit
}

if ( $ARGV[0] ) {
	system("$clear_command");
	print "*** Invalid agrument ***\n
--upgrade		----	'Run Show/Season Data Upgrade'
--getsome		----	'Process outstanding shows and send to downloader'
--debug			----	'Turn on debug output for upgrade'\n\n";
	   exit;
	   }
	   



START:
system($clear_command);
print "####################################################\n";
print "##########       Welcome to Showdy Pi        #######\n";
print "####################################################\n";
print "\nPlease select your option from the list below.\n
1. Add new shows to your Lookout database.\n
2. View\\Remove shows from your Lookout database.\n
3. Configure Shows and their Seasons.\n
4. Configure your Usenet and Downloader details.\n
5. Manual Show Grab.\n
6. Manual database upgrade (updates season/episode information)\n
7. Quit\n

Choice: ";

chomp (my $choice = <STDIN>);
unless ($choice =~ m/[1 2 3 4 5 6 7]/ ) {
	goto START
}


if ( $choice =="1") {
	system("clear");
	my $show;
	my $watching = 0;
	SHOW_SEARCH:
	if($watching ==1) {
		$show =~ s/\+/ /g;
		print " !!! You are already monitoring that show! \n"
	}
	print "Enter a TV name to search [\\q to quit]: ";
	chomp ($show = <STDIN>);
	my $display_show = $show;
	$show =~ s/\s/+/g;
		if( ($show eq '\q') || ($show eq '\Q') ) {
			goto START 
		}
	unless($show) {goto SHOW_SEARCH}
	system($clear_command);		
	print "Searching for \"$display_show\". Please wait.........\n";
	my $search_res = $showdy->search($show);
	if($search_res) {
		if ($search_res =~ m/invalid API/ ) {
			warn "Invalid API Key. Please setup your API key\n";
			sleep 2;
			goto START;
		}
		my $showid = $showdy->display_results();

			my $exists = $showdy->check_watching($showid);
				if ( ! $exists ) {
				my $data = $showdy->return_show($showid);
				$showdy->add_show($data);
				system($clear_command);
				print "Successfully imported episodes into your database.......\n\n";
				sleep 2;
				goto START;
			}
			else {
				  $watching =1;
				  goto SHOW_SEARCH;
			 }
	}
	else{ Showdy::no_matches($show)	}

}

if ( $choice =="2") {
	my %watching;
	system("$clear_command");
	my $watching = $showdy->list_lookout();
	    
	    if ( @$watching ) {
		printf("%-48s %-18s\n", "Showname", "Category");
		print "----------------------------------------------------------\n";
	foreach my $show (@$watching) {
		my ($val,$data) = each @$watching;
		$val++;
		$watching{$val} = $data->{tvdb_id};
	    printf("%-48s %-18s\n", "$val. $data->{showname}",  "$data->{category}");
		}
		print "----------------------------------------------------------\n\n";
		REMOVE_CHOICE:
		print "Select a show to remove from your lookout table [\\q to return]: ";
		chomp (my $choice = <STDIN>);
		if ( ($choice eq '\q') || ($choice eq '\Q')  ) {
			goto START;
		}
		unless ( exists $watching{$choice} ) {
			print " !! Invalid selection !!\n";
			goto REMOVE_CHOICE;
		}
		print "This will completely remove this show from your database!! Are you sure?: ";
		chomp (my $del_opt = <STDIN>);
		lc($del_opt);
			if ( ($del_opt eq 'y') || ($del_opt eq 'yes') ) {
				my $deleted = $showdy->delete_show($watching{$choice});
				sleep 1;
				goto START
			}
			else { goto REMOVE_CHOICE }
	}
	else {print "!!!!! There are no shows in your database. Please add some !!!!!\n\n\n";
			sleep 3;
			goto START
			}
}

if ( $choice =="3" ) {
	my %watching;
	SEASONS_CHOICE:
	system("$clear_command");
	my $watching = $showdy->list_lookout();
	    
	    if ( @$watching ) {
		printf("%-48s %-18s\n", "Showname", "Category");
		print "----------------------------------------------------------\n";
	foreach my $show (@$watching) {
		my ($val,$data) = each @$watching;
		$val++;
		$watching{$val} = $data->{tvdb_id};
	    printf("%-48s %-18s\n", "$val. $data->{showname}",  "$data->{category}");
		}
		print "----------------------------------------------------------\n\n";
		
		print "Select a show to configure episodes [\\q to return]: ";
		chomp (my $choice = <STDIN>);
		if ( ($choice eq '\q') || ($choice eq '\Q')  ) {
			goto START;
		}
		unless ( exists $watching{$choice} ) {
			print " !! Invalid selection !!\n";
			sleep 1;
			goto SEASONS_CHOICE;
		}
	my $seasons = $showdy->get_show_seasons($watching{$choice});
	SEASONS_CHOICE2:;
	system("$clear_command");
	my %season_list;
	print "============================================================\n";
	print " $seasons->[0]->{showname}\n";
	print "============================================================\n";
	print "\n$seasons->[0]->{overview}\n\n";
	print "============================================================\n";
	print " Seasons available \n";
	print "============================================================\n\n";
	foreach my $look (@$seasons) {
		print "$look->{season}. Season $look->{season}\n";
		$season_list{ $look->{season} } = "$watching{$choice}";
	}
	print "\n==========================================================\n\n";

	print "Select a Season to edit its episodes [\\q to return]: ";
	chomp (my $season_sel = <STDIN>);
		if ( ($season_sel eq '\q') || ($season_sel eq '\Q')  ) {
			goto SEASONS_CHOICE;
		}
		unless (exists $season_list{$season_sel} ) {
			print " !! Invalid Selection \n";
			sleep 2;
			goto SEASONS_CHOICE2;
		}
	EPISODE_SELECT:
	my $ep_watching = $showdy->get_episodes_watching($season_sel,$watching{$choice});
	system ("$clear_command");
	print "=====================================================================\n";
	print " $seasons->[0]->{showname} Season $season_sel\n";
	print "=====================================================================\n"; 
	printf("%-5s %-50s %-10s\n", "Ep.", "Title", "Downloaded");
	print "=====================================================================\n";
	my %ep_nums;
	foreach my $eppy (@$ep_watching) {
		$ep_nums{$eppy->{episode}} = [ $watching{$choice}, $eppy->{downloaded} ];
		$eppy->{downloaded} =~ s/0/No/g;
		$eppy->{downloaded} =~ s/1/Yes/g;
		printf ("%-5s %-55s %-10s\n", "$eppy->{episode}.", "$eppy->{title}", "$eppy->{downloaded}");
		
	}

	print "---------------------------------------------------------------------\n\n";
    print "Enter an episode to toggle Downloaded \"Yes/No\".\n'a' to set all to yes.\n'n' to set all to no\n[\\q to go back]: ";
    chomp (my $ep_sel = <STDIN>);
		if ( ($ep_sel eq '\q') || ($ep_sel eq '\Q')  ) {
			goto SEASONS_CHOICE2;
		}
		if ( ($ep_sel eq 'a') || ($ep_sel eq 'n') ) { 
			$showdy->ep_mark_all_down($season_sel,$watching{$choice}, $ep_sel)
		}

		unless ( exists $ep_nums{$ep_sel} ) {
			print " !! Invalid episode selection !!\n";
			goto EPISODE_SELECT;
		}
		$showdy->update_episode($ep_sel,$season_sel,$ep_nums{$ep_sel});
		goto EPISODE_SELECT;
	}
	else {print "no shows\n";
		  sleep 2;
		  goto START
		  }

}

if ( $choice =="4" ) {
	$showdy->update_config;
}

if ( $choice =="5" ) {
	$debug =1;
	$showdy->getsome;
	goto START
}

if ( $choice =="6" ) {
	$debug =1;
	$showdy->global_upgrade;
	goto START
}

if ( $choice =="7" ) {
	print "Bye!\n"
}

sub load_config {
	my $dbh = shift;
	my $sth = $dbh->prepare("SELECT * FROM config");
	$sth->execute();
	my $config = $sth->fetchall_arrayref({});
	return $config->[0];
}

package Showdy;

sub new {
	my ( $class, $self ) = @_;
		unless ( ref $config eq 'HASH' ) {
			return {error => "Hash ref to config required."}
		}
	bless $self, $class;
	
	return $self;
}

sub get_from_newz {
	my $self = shift;
	my $data  = shift;
	my @return;
    my $ua = LWP::UserAgent->new(ssl_opts => {
                             verify_hostname => 0, 
                             SSL_verify_mode => 0x00,
                             PERL_LWP_SSL_VERIFY_HOSTNAME => 0,
                             
                            });   
    $ua->agent("ShowdyPi/0.1 ");
	my $category = '5030';
	$self->{newznab_url} .= "&apikey=$self->{newznab_api}";
	$self->{newznab_url} .= "&rid=";
		foreach my $show (@$data) {
			if ($debug =="1") {
				print "Starting Newznab query for $show->{showname}: Seaons $show->{season} Episode $show->{episode}\n"
			}
			my $best_q = 0;
			my $max_size = ( $self->{max_size} * 1024 * 1024);
			my %return;
			if ( $show->{category} eq 'HD' ) {
				$category = '5040'
			}
			
			my $grab_url = "$self->{newznab_url}$show->{tvrage_id}&season=$show->{season}&ep=$show->{episode}&extended=1&cat=$category\n";
			my $dl = $ua->get($grab_url);

				if($dl->{_content} =~ m/Incorrect user credentials/){
					print "Bad Credentials - check Newznab API key\n";
					next;
				}
				if ( $dl->{_msg} =~ m/Can't connect to/ ) {
					print "*** Error connecting to '$self->{newznab_url}'\n*** Please check your Newznab URL!\n";
					next;
				}
			my $do =  XML::Simple->new();
			my $ref = $do->XMLin($dl->{_content});   
			
			if($ref->{channel}->{'newznab:response'}->{total} == "0" ) {
				$return{error} = "No hits";
				push @return, \%return   
			}
			
			if($ref->{channel}->{'newznab:response'}->{total} > 1 ) {
        
			foreach my $hits (@{$ref->{channel}->{item}}) {
            
				if($hits->{enclosure}->{length} > $max_size){print "$hits->{enclosure}->{length} is too big for $max_size (your max size)\n";next}
        
				   if( ($hits->{enclosure}->{length} < $max_size) && ($hits->{enclosure}->{length} > $best_q) ){
						$best_q = $hits->{enclosure}->{length};
						$return{get_url}   = "$hits->{enclosure}->{url}";
						$return{season}    = $show->{season};
						$return{episode}   = $show->{episode};
						$return{tvdb_id}   = $show->{tvdb_id};
						$return{tvrage_id} = $show->{tvrage_id};
						$return{title}     = $show->{title};
							   
						}
				
						}
					push @return, \%return;
		
					}
					if($ref->{channel}->{'newznab:response'}->{total} == "1" ) {
						if( $ref->{channel}->{item}->{enclosure}->{length} > $max_size ) {next}
							 if( ($ref->{channel}->{item}->{enclosure}->{length} < $max_size) && ($ref->{channel}->{item}->{enclosure}->{length} > $best_q) )
							 {
								print "NOW is:   $ref->{channel}->{item}->{enclosure}->{length}\n";
								 $return{get_url}   = "$ref->{channel}->{item}->{enclosure}->{url}";
								 $return{season}    = $show->{season};
								 $return{episode}   = $show->{episode};
								 $return{tvdb_id}   = $show->{tvdb_id};
								 $return{tvrage_id} = $show->{tvrage_id};
								 $return{title}     = $ref->{channel}->{item}->{title};

					  }
							 push @return, \%return
					}
   
		
		}
return \@return;
}

sub got_show {
	my ($self, $tvdb_id,$season,$episode) = @_;
	my $sth = $self->{dbh}->prepare("UPDATE episodes
									SET downloaded = '1'
									WHERE tvdb_id = ?
									AND season = ?
									AND episode = ?");
	$sth->execute($tvdb_id,$season,$episode);

}

sub send_to_nzbget {
	my $self = shift;
	my $nzbs = shift;
	my $server_url;
	 foreach my $nzbget (@$nzbs) {
		if(exists $nzbget->{error}) {print "No hits\n";next}
	
        if ( $self->{ssl_downloader} eq "y" ){
			$server_url = "https://$self->{nzbget_username}:$self->{nzbget_password}\@$self->{nzget_url}:$self->{nzbget_port}/xmlrpc" 
			}
        else { $server_url = "http://$self->{nzbget_username}:$self->{nzbget_password}\@$self->{nzget_url}:$self->{nzbget_port}/xmlrpc"  }     
        my $server = Frontier::Client->new(url => $server_url,) ;
        my $priority     =  "0";
        my $AddToTop     = $server->boolean("0");
        my $method       = "appenurl";
        my $result	 	  = $server->call("appendurl",($nzbget->{showname},$self->{nzb_category},$priority,$AddToTop,$nzbget->{get_url}) ) ;
			if( $$result =="1") {
				$showdy->got_show( $nzbget->{tvdb_id},$nzbget->{season},$nzbget->{episode} );
			}
		if ($debug =="1") {
			if ($$result =="1") {$$result = 'ok'}
				else {$$result = 'failed'}
			print "Result after sending to NZBGet is: $$result\n"
			}
	 }
}

sub getsome {
	my $self = shift;
	my $manual = shift;
	my $now = time();
	my $newz_results;
	my $query = "SELECT e.*, l.tvrage_id as tvrage_id, l.category, l.showname
				  FROM episodes e 
				  JOIN lookout l ON e.tvdb_id = l.tvdb_id 
				  WHERE downloaded=0 
				  AND air_date <= ?
				  ORDER by season,episode";

	my $sth = $self->{dbh}->prepare($query);
	$sth->execute($now);
	my $results = $sth->fetchall_arrayref({});
	if ( scalar @$results >0 ) {
			$newz_results = $showdy->get_from_newz($results);
		}
	else { if ($debug=="1"){print "All shows up to date\n";sleep 2 } 
			else {return}
		}
	if ( $self->{downloader} eq 'nzbget' ) {
		$showdy->send_to_nzbget($newz_results);
	}
	if ($manual eq 'manual') {
		exit
		}
		
}
sub global_upgrade {
	my $self = shift;
	my $manual = shift;
	my $lookout_ids = $showdy->get_tvdb_ids();
	foreach my $show (@$lookout_ids) {
		$self->add_seasons($show);
	}
	if ($manual eq 'manual') {
		exit
		}

}

sub get_tvdb_ids {
	my $self = shift;
	my $sth = $self->{dbh}->prepare("SELECT distinct(tvdb_id), showname FROM lookout");
	$sth->execute();
	$sth->fetchall_arrayref({});
}

sub update_config {
	my $self  = shift;
	system("$clear_command");
	print "========= Usenet Configuration =========\n\n";
	if ( $self->{firstrun} == "1" ) {
	print "*** This appears to be the first time you've run Showdy Pi ***\n\n"
	}
	print "Modify your configuration below. [brackets contain current config]\n\n";
	DOWNLOADER:
	print "What type of Usenet downloader do you use (nzbget or sabnzbd). ['$self->{downloader}'] : ";
		chomp (my $downloader = <STDIN>);
			unless ( ($downloader eq 'nzbget') || ($downloader eq 'sabnzbd') ) {
				goto DOWNLOADER
			}
	if ( $downloader eq 'sabnzbd' ) { 
		print "SabNZBd integration is not complete yet. Sorry!\n";
		#$showdy->configure_sab
		goto DOWNLOADER
		}
	if ( $downloader eq 'nzbget' ) { 
		$showdy->configure_nzbget
	}
	NEWZNAB_URL:
	my $display_newznab_url = $self->{newznab_url};
	$display_newznab_url =~ s/\/api\?t=tvsearch//;
	print "Enter the base NewzNab URL [$display_newznab_url]: ";
	chomp (my $newznab_url = <STDIN>);
		unless ( $newznab_url ) {
			print "*** Please enter a valid NewzNab URL ***\n";
			goto NEWZNAB_URL
		}
		my $slash = substr($newznab_url,-1);
			if ($slash eq '/') {chop $newznab_url}
		$newznab_url .= "/api?t=tvsearch";
	NEWZNAB_API:
	print "Enter your NewzNab API Key [$self->{newznab_api}]: ";
		chomp (my $newznab_api = <STDIN>);
		unless ( $newznab_api ) {
			print "*** Please enter a valid NewzNab API ***\n";
			goto NEWZNAB_API
		}
	TRAKT_API:
	print "Enter your Trakt API [$self->{trakt_api}]: ";
		chomp (my $trakt_api = <STDIN>);
		unless ( $trakt_api ) {
			print "*** Please enter a valid Trakt API Key ***\n";
			goto TRAKT_API		
		}
	MAX_SIZE:
	print "Max size of show download in MB [$self->{max_size}]: ";
		chomp (my $max_size = <STDIN>);
		unless ( $max_size ) {
			print "*** Please enter a valid max size ***\n";
			goto MAX_SIZE
		}
		unless ( $max_size =~ m/[1-99999]/) {
			print "*** Please enter a valid max size ***\n";
			goto MAX_SIZE
		}
	$self->{newznab_url}		= $newznab_url;
	$self->{newznab_api}		= $newznab_api;
	$self->{trakt_api}			= $trakt_api;
	$self->{max_size}			= $max_size;

	my $sth = $self->{dbh}->prepare("UPDATE config
									  SET trakt_api = ?, newznab_api =?, sab_api = ?,
									  sab_url = ?, sab_port = ?, newznab_url = ?,
									  max_size = ?, nzget_url = ?, nzbget_username = ?,
									  nzbget_password = ?, nzbget_port = ?, downloader = ?,
									  ssl_downloader = ?, nzb_category =?, firstrun='0' ");
	eval { $sth->execute( $self->{trakt_api},$self->{newznab_api},$self->{sab_api},
					$self->{sab_url},$self->{sab_port},$self->{newznab_url},
					$self->{max_size},$self->{nzbget_url},$self->{nzbget_username},
					$self->{nzbget_password},$self->{nzbget_port},$self->{downloader},
					$self->{ssl_downloader}, $self->{nzbget_category} ) } ;
	
	unless ($@) {
		print "\n**** Configuration Updated ****\n";
		sleep 2;
		goto START
		}

				   
							 
}

sub configure_nzbget {
	my $self = shift;
	system("$clear_command");
	print "========= NZBGet Configuration =========\n\n";
	NZB_PORT:
	print "What port is your NZBGet server running on ['$self->{nzbget_port}' ]: ";
	chomp (my $nzbget_port = <STDIN>);
		unless ($nzbget_port =~ m/(\d+)/ ) {
			print "*** Please select a valid port ***\n";
			goto NZB_PORT
		}
	NZB_USER:
	print "What is your nzbget username [$self->{nzbget_username}]: ";
	chomp (my $nzbget_username = <STDIN>);
		unless ( $nzbget_username ) {
			print "*** Please enter a valid nzbget username ***\n";
			goto NZB_USER
		}
	NZB_PASSWORD:
	print "What is your nzbget password [$self->{nzbget_password}]: ";
	chomp (my $nzbget_password = <STDIN>);
		unless ( $nzbget_password ) {
			print "*** Please enter a valid nzbget password ***\n";
			goto NZB_PASSWORD
		}
	NZB_URL:
	print "What is your nzbget url, without 'http(s)' prefix [$self->{nzget_url}]: ";
	chomp (my $nzbget_url = <STDIN>);
		unless ( $nzbget_url ) {
			print "*** Please enter a valid nzbget URL ***\n";
			goto NZB_URL
		}	
	my $url_prefix = substr ($nzbget_url,0,5);
		lc($url_prefix);
    
    if ( $url_prefix eq 'https' ) {
		$url_prefix = "$url_prefix" . "://";
		$nzbget_url =~ s/$url_prefix//;
	}
	if ( $url_prefix eq 'http:' ) {
		chop $url_prefix;
		$url_prefix = "$url_prefix" . "://";
		$nzbget_url =~ s/$url_prefix//;
	}
	NZB_SSL:
	print "Are you using SSL on your nzbget server [y/n] : ";
	chomp (my $ssl_downloader = <STDIN>);
	lc($ssl_downloader);
	unless ( ($ssl_downloader eq 'y') || ($ssl_downloader eq 'n') ) {
		print "*** Please enter 'y' or 'n' to indicate if your NZBget server is using SSL or not ***\n";
		goto NZB_SSL
	}
		if($ssl_downloader eq 'y') {
			print "\n*** NOTICE: Sending NZBs to NZBGet via an SSL connection may display warning messages\n";
			print "if you are using self signed SSL certificates. The NZB information will still be sent\n";
			print "but the routine will output WARNING messages. This can be ignored if you are happy to\n";
			print "use self-signed certs. A future release will enable addition of the certs as a config\n";
			print "option, removing the warnings.\n";
			print "**** TLDR; When SSL is on you may get some warnings message. The system is still working though!\n\n";
		}
	NZB_CATEGORY:
	print "What NZBGet category to use for TV Shows: ";
	chomp (my $nzbget_category =<STDIN>);
	unless ( $nzbget_category ) {
		print "*** Please enter a valid category ***\n";
		goto NZB_CATEGORY
	}
		
	# write them to instance
	$self->{downloader}			= 'nzbget';
	$self->{nzbget_port} 		= $nzbget_port;
	$self->{nzbget_username}	= $nzbget_username;
	$self->{nzbget_password}	= $nzbget_password;
	$self->{nzbget_url}			= $nzbget_url;
	$self->{nzbget_category}	= $nzbget_category;
	$self->{ssl_downloader}		= $ssl_downloader;
	$self->{sab_url}			= "disabled";
	$self->{sab_api}			= "disabled";
	$self->{sab_port}			= "disabled";
	
}

sub ep_mark_all_down {
	my ( $self, $season, $tvdb_id, $direction ) = @_;
	 if ( $direction eq 'a' ) {$direction = "1"}
	 else {$direction = "0"}
	my $sth = $self->{dbh}->prepare("UPDATE episodes set downloaded = ?
									 WHERE tvdb_id = ?
									 AND season = ?");
	$sth->execute($direction,$tvdb_id, $season);									 
}

sub update_episode {
	my ( $self, $episode, $season, $unwrap ) = @_;
	my ($tvdb_id, $downloaded) = (@$unwrap[0],@$unwrap[1]);
	 if ( $downloaded == "0" ) {$downloaded ="1"}
		 else {$downloaded = "0"}
	my $sth = $self->{dbh}->prepare("UPDATE episodes set downloaded = ? 
									 WHERE tvdb_id = ?
									 AND season = ?
									 AND episode =?");
	$sth->execute($downloaded,$tvdb_id,$season,$episode);	
	
}

sub get_episodes_watching {
	my ( $self, $season, $tvdb_id) = @_;
	my $sth = $self->{dbh}->prepare("SELECT tvdb_id, episode, title, downloaded 
									 FROM episodes WHERE tvdb_id = ?
									 AND season = ?");
	$sth->execute($tvdb_id,$season);
	$sth->fetchall_arrayref({});
}

sub get_show_seasons {

	my ( $self, $tvdb_id ) = @_;
	my $sth = $self->{dbh}->prepare("select distinct(season), showname, overview from lookout l  
									  join episodes e on l.tvdb_id = e.tvdb_id
									  where l.tvdb_id = ?
									  group by season");
	$sth->execute($tvdb_id);
	return $sth->fetchall_arrayref({});
	
}

sub delete_show {
	my ($self, $delete) = @_;

#EVAL ?????, cascade on delete???
	my $sth = $self->{dbh}->prepare("DELETE FROM lookout WHERE tvdb_id = ?");
	$sth->execute($delete);
	my $sth2 = $self->{dbh}->prepare("DELETE FROM episodes WHERE tvdb_id = ?");
	$sth2->execute($delete);

	
}

sub search {
    my ($self, $search)	= @_;
    if( ! $search ) {
		print "Please enter a show name to search on\n";
		return 1;
	}
	my $ua = LWP::UserAgent->new;
	my $data = $ua->get( $self->{search_url} . $search);
		if( $data->{_msg} =~ m/Can't connect to/ ) {
			print "*** Can't connect to '$self->{search_url}'\n*** Check your internet connection, DNS settings or that the site us up\n";
			exit
		}
	my $decode = JSON::XS->new->utf8->decode ($data->{_content});
		if (ref $decode eq 'HASH' ) {
			return $decode->{error}
		}
		if (! @$decode  ) {
			return undef;
		}

		else { $self->{json} = $decode }

	return $self;

}


sub display_results {
	my $self = shift;
	my %choice;
	my $wrong_sel = 0;
	system("clear");
		my @keys = keys $self->{json}[0];
		printf("%-48s %-18s %-20s %-10s\n", "Showname", "Network", "County", "Year");
		print "-----------------------------------------------------------------------------------------------------\n";
		my $cnt = 0;
		foreach my $key ( @{$self->{json}} ) {
			$cnt = $cnt+1;
			$choice{$cnt} = $key->{tvdb_id};
			printf "%-48s %-18s %-20s %-8s\n", "$cnt. $key->{title}","$key->{network}","$key->{country}","$key->{year}";
		}	
		print "-----------------------------------------------------------------------------------------------------\n\n";		
		SEL_MULSHOW:
		if($wrong_sel =="1") {print "**Invalid Selection!\n" }
		$wrong_sel = 0;
		print "Enter a show number to add to your database [\\q to exit]: ";
		chomp (my $show_num = <STDIN>);
		if( ($show_num eq '\q') || ($show_num eq '\Q') ) {
			goto START 
		}
		unless( exists $choice{$show_num} ) {
				$wrong_sel = 1;
				goto SEL_MULSHOW
				}
		return $choice{$show_num}

}

sub add_show {
	my ($self,$data) = @_;
	print "Adding Show to database. Please wait.....\n";
	my $sth = $self->{dbh}->prepare("INSERT INTO lookout
									  (tvdb_id, showname, imdb_id, tvrage_id, overview, category)
									  VALUES
									  (?,?,?,?,?,?)");
	eval { $sth->execute($data->{tvdb_id}, $data->{title}, $data->{imdb_id},
						  $data->{tvrage_id}, $data->{overview}, "HD") };
		unless($@) {
			add_seasons($self, $data)
		}
							 
	}

sub add_seasons {
	my ($self, $data)	=	@_;
    my $url        	= "https://api.trakt.tv/show/seasons.json/$self->{trakt_api}/$data->{tvdb_id}";
    my $season_url 	= "https://api.trakt.tv/show/season.json/$self->{trakt_api}/$data->{tvdb_id}/";
	my $ua				= LWP::UserAgent->new();
	my $sth			= $self->{dbh}->prepare("INSERT into episodes
												 (tvdb_id, season, episode, title, downloaded, air_date)
												 VALUES
												 (?,?,?,?,'0',?)" );
	my $no_seasons 	= $ua->get($url);
	my $season_json	= JSON::XS->new->utf8->decode ( $no_seasons->{_content} );
		foreach (@$season_json) {
			my $no_episodes = $ua->get("$season_url$_->{season}");
			my $episodes = JSON::XS->new->utf8->decode ( $no_episodes->{_content} );
						foreach my $eps ( @$episodes ) {
							unless ( $eps->{season} =="0" ) {
								#print "Adding $data->{title} Season $eps->{season} Episode $eps->{episode}   ";
								eval { $sth->execute($data->{tvdb_id}, $eps->{season}, $eps->{episode},
										   $eps->{title}, $eps->{first_aired}) };
									   
								if($@) {
								   if ( $debug =="1" ) {
								   print "**** Skipping '$data->{showname}' Season $eps->{season} Episode $eps->{episode}, already have this episode's details ****\n"
								   }
									next;
												
								}
								else {
									if ( $data->{showname} ) {print "Adding '$data->{showname}' Season $eps->{season} Episode $eps->{episode}\n" }
									else {print "Adding '$data->{title}' Season $eps->{season} Episode $eps->{episode}\n" }
								
								}
						} 
				}
		
		}
}

sub return_show {
	my $self 	= shift;
	my $showid 	= shift;
	foreach my $show ( @{$self->{json}} ) {
			if ( $show->{tvdb_id}  == $showid ) {
			return $show
			}
	}
	
return "No matches for showid '$showid'"
	}

sub no_matches {
	my $term = shift;
	print "****** No matches found for '$term'\n";
	goto SHOW_SEARCH
}

sub list_lookout {
my ($self, $showid) = @_;
	my $sth = $self->{dbh}->prepare("SELECT tvdb_id, showname, overview, category
									  FROM lookout");
	$sth->execute();
	return $sth->fetchall_arrayref({});
	
}

sub check_watching {
	my ($self, $showid) = @_;
	my $sth = $self->{dbh}->prepare("SELECT COUNT(*)
							 FROM lookout
							 WHERE tvdb_id = ?");
	$sth->execute($showid);
	return $sth->fetchrow();
	}

sub new_dbh {
    my $db_path;
    if (-e "$showdy_path/showdy.db") {
		$db_path = "$showdy_path/showdy.db"
	}
	else {$db_path = "showdy.db"}
    my $dbh= DBI->connect("DBI:SQLite:dbname=$db_path","","",
			{sqlite_use_immediate_transaction => 1,AutoCommit => 1,RaiseError => 1, PrintError => 0,}) 
			or die $DBI::errstr;
    $dbh->do("PRAGMA synchronous = OFF");
    $dbh->do("PRAGMA encoding = 'UTF-8'"); 
    $dbh->{TraceLevel} = 0;
    return $dbh;
}
