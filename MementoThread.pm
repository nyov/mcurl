package MementoThread;

use MementoParser;
use URI;

use FindBin;
use lib "$FindBin::Bin";

sub printDebug;

sub new {
	my $self = {
		URI => undef, #String, This is the input URI that we need to retrieve its mementos
		Text => undef, #String, the URI content
		RedirectionList => undef,
		FollowEmbedded => 0,
		TimeGate => "http://mementoproxy.cs.odu.edu/aggr/timegate",
		Mode => 0, #0 is the default mode (Relaxed)
		RedirectionPolicy => undef,
		DateTime => undef,
		Debug => 0,
		Override => 0,
		RobotsTG => undef,
		ReplaceFile => undef,
		Headers => {
			status=> undef,
			vary => 0, #Vary default false
			MementoDT => undef,
			Link => undef,
			contentType => undef,
			Location => undef
		},
		Info => {
			Type => 'original',
			Original => undef,
			Okay => 0,
			TimeGate => undef,
			TimeMap => undef,
			Location => undef
		}
	};
	bless $self, 'MementoThread';
	$self->printDebug("Starting a new memento thread.");
	return $self;
}

sub printDebug {
	my ( $self, @msg ) = @_;
	if($self->{Debug} == 1){
		print "DEBUG: @msg\n";
	}
}

sub setURI {
	my ( $self, $nURI ) = @_;
	$self->{URI} = $nURI if defined($nURI);
}

sub setTimeGate {
	my($self, $lTimeGate) = @_;
	$self->{TimeGate} = $lTimeGate;
}

sub setMode {
	my($self, $lMode) = @_;
	$self->{Mode} = $lMode;
}

sub setRedirectionPolicy {
	my($self, $lRedirectionPolicy ) = @_;
	$self->{RedirectionPolicy } = $lRedirectionPolicy ;
}

sub setDateTime {
	my ($self, $lDateTime) = @_;
	$self->{DateTime } = $lDateTime if defined($lDateTime);
}

sub setDebug {
	my ($self, $lDebug) = @_;
	$self->{Debug} = $lDebug if defined($lDebug);
}

sub setOverride {
	my ($self, $lOverride ) = @_;
	$self->{Override} = $lOverride if defined($lOverride);
}

sub setReplaceFile() {
	my ($self, $lReplaceFile ) = @_;
	$self->{ReplaceFile} = $lReplaceFile if defined($lReplaceFile);
}

sub read_cmd_multi{
	my ($self,$scalar,@arg) = @_;
	$self->printDebug("read_cmd_multi($scalar,@arg);");

	my @out;
	my $sep = $/;
	my $pid = open($child, "-|", @arg);
	defined($pid) || die "can't fork: $!";
	if ($pid) { # parent
		$/ = undef if $scalar;
		@out = <$child>;
		$/ = $sep;
		close($child) || warn "child process exited $?";
	} else { # child
		($EUID, $EGID) = ($UID, $GID); # suid only
		exec @arg || die "can't exec program: $!";
	}
	return $scalar ? @out[0] : @out;
}

sub read_cmd{
	my ($self,@arg) = @_;
	return $self->read_cmd_multi(1,@arg);
}
sub datetime_flag {
	my ($self) = @_;
	return () unless $self->{DateTime};
	return "-H", "'Accept-Datetime: $self->{DateTime}'";
}
sub timegate_uri {
}
sub head {
	my ($self) = @_;
	$self->printDebug("Starting with head command to determine resource type.");
	my $ret=$self->read_cmd(qw.curl -I --trace.,$self->datetime_flag(),$self->{URI});

	#Start to look to the different Headers options
	$self->parseHeaders($ret);

	#In some cases, we need to lookup to URI format itself
	$self->determineResourceType();
	$self->discover_tg_robots();
	$self->selectTimeGate();

	$self->printDebug("Resource Type: ". $self->{Info}->{Type} );
}

sub selectTimeGate(){
	my ($self) = @_;

	$self->printDebug("Selecting the TimeGate.");
	#override

	if($self->{Override} == 1){
		#The timegate will be as it's in $self->{TimeGate}
		$self->printDebug("Override case:Accepted.");

	} elsif ($self->{Info}->{Type} eq "TimeGate"){
		$self->printDebug("Resource Type is TimeGate case: Accepted.");
		$self->{TimeGate} = $self->{URI};

		#Additional steps required in calling the function the memento
		#or, we can remove one of these fields at all
	} elsif ($self->{Info}->{TimeGate}) {
		$self->printDebug("TimeGate is defined in Link header case: Accepted");
		$self->{TimeGate}= $self->{Info}->{TimeGate} ;

	} elsif (defined($self->{RobotsTG})){
		$self->printDebug("TimeGate is discovered in robots.txt case: Accepted");
		$self->{TimeGate} = $self->{RobotsTG};

	} else {
		$self->printDebug("TimeGate is not changed");
	}
	$self->printDebug("TimeGate: " . $self->{TimeGate});

	return;
}

sub parseHeaders {
	my ($self, $header) = @_;
	$self->printDebug("In parsing header function");
	$_ = $tmp;

	if( m/Memento-Datetime:.*\n/){
		$self->{Headers}->{MementoDT} = substr($&, 18);
	#	print $self->{Headers}->{MementoDT};
	}

	if( m/Vary:.*accept-datetime.*\n/){
		$self->{Headers}->{vary} = 1;
	#	print $self->{Headers}->{vary} ;
	}

	if( m/HTTP\/1\.\d\s\d\d\d\s.*\n/ ){
		$self->{Headers}->{status}= int(substr($&,9,3));
	#	print $self->{Headers}->{status};
	}

	if( m/Content\-Type:.*\n/){
		if( substr($&,14) =~ m/text\// ){
			$self->{FollowEmbedded} = 1;
		}
	}

	if( m/Link:.*\n/ ){
		$self->{Headers}->{Link} =$&;

		my @links = (m/<[^>]*>;\s?rel=\"?[^\"]*\"?/g);

		for(my $i=0 ; $i<= $#links ; $i++){
			@line = split( /;/,$links[$i] ) ;

			if($line[1] =~ m/.*original.*/ ){
				$self->{Info}->{Original} = substr($line[0], 1, length($line[0]) -2);
			} elsif ($line[1] =~ m/.*timegate.*/ ){
				$self->{Info}->{TimeGate} = substr($line[0], 1, length($line[0]) -2);
			} elsif ($line[1] =~ m/.*timemap.*/ ){
				$self->{Info}->{TimeMap} = substr($line[0], 1, length($line[0]) -2);
			}
		}
	}
	if( m/Location:.*\n/ ){
		$self->{Headers}->{Location} = substr($&,10);
	}
	if($self->{Debug} == 1){
		print "DEBUG: Parsing header results: \n\t* Memento-datetime: $self->{Headers}->{MementoDT}\n";
		print "\t* VARY: $self->{Headers}->{vary} \n\t* HTTP Status: $self->{Headers}->{status}\n";
		print "\t* Follow the embedded resources: $self->{FollowEmbedded} \n";
		print "\t* Link (org): $self->{Info}->{Original}\n\t* Link (timegate):$self->{Info}->{TimeGate}\n";
		print "\t* Link (timemap):$self->{Info}->{TimeMap}\n\t* Location: $self->{Headers}->{Location} \n";
	}
}

sub determineResourceType {
	my ($self) = @_;

	#Case 1, 2, 3
	if($self->{status} == 200 && defined($self->{Headers}->{MementoDT})){
		$self->{Info}->{Type} = "Memento";
		if( length( $self->{Info}->{Original} ) != 0) {
			$self->{URI} = $self->{Info}->{Original} ;
			return;
		}
	}

	# Review if the URI in the whiteList
	my $rewrittenURI = $self->unrewriteURI($self->{URI});
	if( length($rewrittenURI) >0){
		$self->{URI} = $rewrittenURI;
		$self->{Info}->{Type} = "Memento";
		return;
	}

	#case 5, 6
	if( $self->{Headers}->{vary} == 1 and $self->{Headers}->{status} eq 302){
		$self->{Info}->{Type} = "TimeGate";
		return;
	}

	if( $self->{Headers}->{status} == 302
			&& length($self->{Info}->{Original} ) != 0){
		#intermdeiate Okay
	} elsif (length($self->{Info}->{Original} ) !=0){
		#Type memento
		#Not Okay
	}

	#Check for the time bubble

	#Get the URI from the memento URI
}

sub discover_tg_robots {
	my ($self, @params) = @_;
	$self->printDebug("Discovering Timegate robots");
	my $robotTG = '';
	my $urlObj = URI->new($self->{URI});
	my $host = "http://".$urlObj->host( ) .'/robots.txt' ;
	my @lines =$self->read_cmd_multi(undef,(qw(curl -L),$host));
	foreach (@lines) {
		if( index($_, 'TimeGate') ==0){
			$robotTG = substr( $_, 9, length ($_)-10);
		} elsif(index($_, 'Archived') ==0){
			if( $_ eq '*' or index($self->{URI}, substr( $_, 10, length ($_)-11)) > -1){
				if($self->{Debug} == 1){
					print "\nDEBUG: A new TimeGate is discovered through (robots.txt): $robotTG";
				}
				$self->{RobotsTG} = $robotTG;
				return;
			}
		}
	}
}

sub process_uri {
	my ($self, @params) = @_;

	$self->printDebug("in process_uri");
	my @command =("curl", @params, $self->datetime_flag());

	#it has a problem with different timegates values
	# Ex. mcurl.pl -I -L --datetime "Fri, 23 July 2009 12:00:00 GMT"  http://lanlsource.lanl.gov/hello
	# Ex. mcurl.pl -I -L --datetime "Fri, 23 July 2009 12:00:00 GMT"  http://mementoproxy.cs.odu.edu/aggr/timegate/http://www.digitalpreservation.gov/

	my $info = $self->{Info};
	my $uri = $self->{TimeGate};
	$uri .= "/$self->{URI}" unless ($info->{TimeGate} or $info->{Type} eq "TimeGate");
	my $result = $self->read_cmd(@command,$uri);

	#based on the type (text/html) and stict/relaxed mode we will force the retrieve embedded via memento method
	return $self->retrieve_embedded($result) if $self->{FollowEmbedded} and $self->{Mode};
	return $result;
}

sub handle_redirection {
	my ($self) = @_;
	$self->printDebug("handle_redirection();");

	#Redirection policy case 1, URI-R has 302
	if( $self->{Headers}->{status} > 299 and $self->{Headers}->{status} < 399 and $self->{Info}->{Type} eq 'original' ){
		$self->printDebug("Redirection policy #1, URI-R: $self->{URI} has a redirection to $self->{Headers}->{Location}");
		my $acceptDateTimeHeader = "";

		my @command=qw(curl -I -L);
		push @command,("-H", "'Accept-Datetime:$self->{DateTime}'");

		push @command, defined( $self->{Info}->{TimeGate} ) ?
			$self->{Info}->{TimeGate} :
			$self->{TimeGate} . "/" . $self->{URI};

		my $results =$self->read_cmd($command);

		#if the status 404 move to the redirected location
		my $redirectionStatus = 404;
		my @redirectionStatusList = ($results =~ m/HTTP\/1\.\d\s\d\d\d\s.*\n/g);

		if($#redirectionStatusList > 0){
			$redirectionStatus = int(substr(@redirectionStatusList[-1],9,3));
		}
		#if( m/HTTP\/1\.\d\s\d\d\d\s.*\n/ ){
		#	$redirectionStatus = int(substr($&,9,3));
		#}

		# the status may be 200, 302, 404
		#if ($redirectionStatus >=300 and $redirectionStatus <400){
			#it's an expected status because the timegate will redirect to the memento
			#TODO
			# should we test the location value?
		#	while( $redirectionStatus >=300 and $redirectionStatus <400 ){
		#		my $newLoc = "";
		#		if( $results =~ m/Location:.*\n/ ){
		#			$newLoc = substr($&,10);
		#		}
		#		$results = `curl -I $newLoc`;
		#		$redirectionStatus = 404;
		#		if( $results =~ m/HTTP\/1\.\d\s\d\d\d\s.*\n/ ){
		#			$redirectionStatus = int(substr($&,9,3));
		#		}
		#	}
		#	print "DEBUG: Status equals ($redirectionStatus), use the original URI\n";
		#	return;
		#}
		if( $redirectionStatus == 200 ){
			#that's ok, use the original URI
			$self->printDebug("Memento redirection status equals ($redirectionStatus), use the original URI");
			return;
			#todo
			#check for the time bubble
		} else{ #Not success nor redirect
			# use the Location URI
			$self->printDebug("Memento redirection status equals ($redirectionStatus), use the redirected URI: $self->{Headers}->{Location}");
			$self->{URI}= $self->{Headers}->{Location} ;
			$self->head();
			return;
		}
	}
}

sub retrieve_embedded {
	#Make sure the syntax of the URI
	my ($self,$pageText) = @_;
	$self->printDebug("In retrieve Embedded resources function");

	my $dumpFile = undef;
	if(defined($self->{ReplaceFile}) ){
		open $dumpFile, ">", $self->{ReplaceFile};
	}

	my $memParser = new MementoParser();
	$memParser->parse($pageText);

	my @oldURIs = $memParser->returnURIs();
	$self->printDebug("Number of embedded resources retrieved: " . $#oldURIs);

	my %hash = map { $_, 'aa'} @oldURIs;
	foreach my $oldURI (keys %hash) {
		my $completeOldURI = $oldURI;

		if(index($oldURI, "http") != 0){
			if(index($self->{URI},'\r')>0 or index($self->{URI},'\n')>0 ) {
				$completeOldURI = substr($self->{URI},0, -2 ). "/".$oldURI;
			} else {
				$completeOldURI = $self->{URI}."/" . $oldURI;
			}
		}

		$self->printDebug($completeOldURI);

		my $embeddedThread = new MementoThread();

		$embeddedThread->setURI($completeOldURI);
		$embeddedThread->setMode(0);
		$embeddedThread->setDateTime($self->{DateTime});
		$embeddedThread->setDebug($self->{Debug});
		$embeddedThread->setOverride($self->{Override});
		$embeddedThread->setTimeGate($self->{TimeGate});
		$embeddedThread->head();

		@param = qw(-L -I);
		$embeddedResult = $embeddedThread->process_uri(@param);

		if( $embeddedResult =~ m/Location:.*\n/ ){
			my $newURI = substr($&,10);
			$pageText =~ s/$oldURI/$newURI/g;

			$self->printDebug("Replace $oldURI");
			$self->printDebug("With $newURI");
			print $dumpFile $oldURI .",".$newURI."\n" if( defined($dumpFile) );
		}
	}
	close $dumpFile if( defined($dumpFile));
	return $pageText;
}

sub unrewriteURI {
	my ($self, $orgURI) = @_;
	$self->printDebug("Try to unrewrite the URI, ");
	if( index($orgURI ,'archive.org/') > -1 or
		index($orgURI ,'webarchive.nationalarchives.gov.uk') > -1 or
		index($orgURI ,'wayback.archive-it.org') > -1 or
		index($orgURI ,'enterprise.archiefweb.eu/archives/archiefweb') > -1 or
		index($orgURI ,'memento.waybackmachine.org/memento/') > -1 or
		index($orgURI ,'www.webarchive.org.uk/waybacktg/memento') > -1
	) {
		my $nHttp = index($orgURI , 'http://' , 10);
		if($nHttp > 1){
			$self->printDebug("Successfully, URI is: ".substr $orgURI,$nHttp);
			return substr $orgURI,$nHttp ;
		}
	} #else
	$self->printDebug("unwriteURI unsuccessful");
	return "";
}

sub process_timemap {
	my ($self, $timemap, @params) = @_;
	$self->printDebug("process_timemap(@_);");
	my $info=$self->{Info};
	my $timeMapURI = undef;

	if(defined($info->{TimeMap})){
		$self->printDebug("Read TimeMap from the Link header ");
		$timeMapURI = $info->{TimeMap};
	}
	#TODO: check if the concatenation between the URI and TimeGate required or not
	else {
		$self->printDebug("Head request to the TimeGate to get the TimeMap");
		my $uri = $self->{TimeGate};
		$uri .= "/$self->{URI}" if $info->{TimeGate} or $info->{Type} eq "TimeGate";

		$_ = $self->read_cmd(qw(curl -I -L), @params, $uri);

		if( m/Link:.*\n/ ){
			my @links = ( m/<[^>]*>;\s?rel=\"?[^\"]*\"?/g );
			foreach $link (@links){
				@line = split( /;/,$link ) ;
				if ($line[1] =~ m/.*timemap.*/ ){
					$info->{TimeMap} = substr($line[0], 1, length($line[0]) -2);
					$timeMapURI = $info->{TimeMap} ;
					$self->printDebug("Head request successfully retrieved the TimeMap ");
				}
			}
		}
	}

	if( not defined($timeMapURI)){
		$self->printDebug("Get the TimeMap by replacing the TimeGate.");
		$timeMapURI = $self->{TimeGate};
		$timeMapURI =~ s/timegate/timemap/g;

		if ( index( $timeMapURI, '/',length($timeMapURI) -3) < 0 ){
			$timeMapURI = $timeMapURI."/";
		}
		$timeMapURI = $timeMapURI.$timemap. '/'.$self->{URI};
	}

	return $self->read_cmd(("curl", @params, $timeMapURI));
}

1;
