#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin";
use MementoThread;
use strict;
use Switch;

die <<USE if (@ARGV < 1);
Usage: mcurl [options...] <url>
Try 'mcurl --help' for more information
USE

my $help  = <<HELP;
 -w, --write-out FORMAT  What to output after completion
     --xattr        Store metadata in extended file attributes
 -q                 If used as the first parameter disables .mcurlrc
 -tm, --timemap link Selects timemap type (Only "link" valid?) it may be link or html
 -tg, --timegate URI[,URI[,URI...]] Prioritize specified timegates
 -dt, --datetime DATE Select the date in the past (RFC822 format, eg. Thu, 31 May 2007 20:35:00 GMT)
 -mode <strict|relaxed> Specify mcurl embedded resource policy, default value is relaxed
HELP

my $timemap;
my $outfile;
my @curlargs;

my $mt = new MementoThread();
my $uri = pop @ARGV if @ARGV > 1;

while (my $arg = shift @ARGV){
	switch ($arg) {
		#case ['--dateTimeRange'] {}
		case ['-o', '--output']	  { push @curlargs, ($arg, $outfile = shift @ARGV); } 
		case ['-V', '--version']  { die "mcurl 0.86 Memento Enabled curl based on " . `curl -V`; }
		case ['-tm','--timemap']  { $timemap = index($ARGV[0],'-') == 0 ? 'link' : shift @ARGV; }
		case ['-tg','--timegate'] { $mt->setTimeGate(shift @ARGV); }
		case ['-dt','--datetime'] { $mt->setDateTime(shift @ARGV); }
		case ['--help'] 	  { die `curl --help`=~ s/curl/mcurl/gr . $help; }
		case ['--replacedump'] 	  { $mt->setReplaceFile(shift @ARGV); }
		case ['--mode'] 	  { $mt->setMode(shift @ARGV eq 'strict' ? 1 : 0); }
		case ['--debug'] 	  { $mt->setDebug(1); }
		case ['--override'] 	  { $mt->setOverride(1); }
		else { push @curlargs, $arg }
	}
}

print $mt->{ReplaceFile};

$mt->setURI($uri);
$mt->head();
$mt->handle_redirection();

my $result = $timemap ? 
	$mt->process_timemap( $timemap , @curlargs ) : 
	$mt->process_uri( @curlargs );

if(! $outfile){
	my $bar = "-" x 30;
	print <<CNTNT;
$bar THE PAGE CONTENT $bar
$result
$bar END PAGE CONTENT $bar
CNTNT
}
