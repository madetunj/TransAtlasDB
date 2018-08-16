#!/usr/bin/env perl
use warnings;
use strict;
use Pod::Usage;
use Getopt::Long;
use File::Spec;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path $0) . '/lib';
use CC::Create;

our $VERSION = '$ Version: 1 $';
our $DATE = '$ Date: 2016-10-25 13:19:08 (Tue, 25 Oct 2016) $';
our $AUTHOR= '$ Author:Modupe Adetunji <amodupe@udel.edu> $';

#--------------------------------------------------------------------------------

our ($verbose, $help, $man, $efile);
our ($sqlfile,$connect);
my ($dbname,$username,$password,$location,$fbname, $ffastbit);
my ($sth,$dbh,$schema); #connect to database;

#--------------------------------------------------------------------------------

sub printerr; #declare error routine
our $default = DEFAULTS(); #default error contact
processArguments(); #Process input

#output 
printerr ("NOTICE:\t Connection Details:\n\t\tUsername = $username\n\t\tPassword = $password\n\t\tMySQL database = $dbname\n");
printerr ("\t\tFastBit folder = $ffastbit\n");
printerr ("NOTICE:\t Summary in log file $efile\n");
printerr "-----------------------------------------------------------------\n";
print LOG "TransAtlasDB Completed:\t", scalar(localtime),"\n";
close (LOG);

#--------------------------------------------------------------------------------

sub processArguments {
	my @commandline = @ARGV;
  GetOptions('verbose|v'=>\$verbose, 'help|h'=>\$help, 'man|m'=>\$man, 'databasename|d=s'=>\$dbname,
		'username|u=s'=>\$username, 'password|p=s'=>\$password, 'location|l=s'=>\$location,
		'fastbitname|n=s'=>\$fbname ) or pod2usage ();

  $verbose ||=0;
	$help and pod2usage (-verbose=>1, -exitval=>1, -output=>\*STDOUT);
  $man and pod2usage (-verbose=>2, -exitval=>1, -output=>\*STDOUT);  
  my $get = dirname(abs_path $0); #get source path
  
	if (!$password) {
		`find $get/\.connect.txt` or pod2usage(-msg=>"ERROR:\t Unavailable Connection details\nERROR:\t Required argument -p (MySQL password) not provided.");
		$connect = $get.'/.connect.txt';
	}
	if ($connect){
		my %all_details = %{connection($connect, $default)}; #get connection details
		$dbh = mysql($all_details{'MySQL-databasename'}, $all_details{'MySQL-username'}, $all_details{'MySQL-password'}); #connect to mysql
		$ffastbit = fastbit($all_details{'FastBit-path'}, $all_details{'FastBit-foldername'});  #connect to fastbit
		`find $ffastbit` or pod2usage("ERROR:\t Fastbit folder '$ffastbit' can not found. Run INSTALL-tad.pL");
		$username = $all_details{'MySQL-username'}; $password = $all_details{'MySQL-password'}; $dbname = $all_details{'MySQL-databasename'};
		printerr "-----------------------------------------------------------------\n";
		printerr ("NOTICE:\t Retrieved the following connection details.\n");
	} else {
		$dbname = "transatlasdb" if (! $dbname);
		$fbname = "transatlasfb" if (! $fbname);
		$username = "root" if (! $username);
		if (! $location) {$location = `pwd`; chomp $location;}
	
		#make sure connection details are accurate
		$dbh = mysql($dbname, $username, $password); #connect to mysql
	
		#find fastbit location or die;
		$ffastbit = fastbit($location, $fbname);
		`find $ffastbit` or pod2usage("ERROR:\tFastbit folder '$ffastbit' can not found. Run INSTALL-tad.PL");
	
		open(CONNECT, ">$get/\.connect.txt"); 
		my $connectcontent = "MySQL\n  username $username\n  password $password\n  databasename $dbname\nFastBit\n  path $location\n  foldername $fbname\n";
		print CONNECT $connectcontent; close (CONNECT);
		printerr "-----------------------------------------------------------------\n";
		printerr ("NOTICE:\t Stored the following connection details.\n");
	}
	#setup log file
	$efile = @{ open_unique("db.tad_status.log") }[1];
  open(LOG, ">>", $efile) or die "\nERROR:\t cannot write LOG information to log file $efile $!\n";
  print LOG "TransAtlasDB Version:\t",$VERSION,"\n";
  print LOG "TransAtlasDB Information:\tFor questions, comments, documentation, bug reports and program update, please visit $default \n";
  print LOG "TransAtlasDB Command:\t $0 @commandline\n";
  print LOG "TransAtlasDB Started:\t", scalar(localtime),"\n";
	
	
}

#--------------------------------------------------------------------------------

=head1 SYNOPSIS

 connect-tad.pL [arguments]

 Optional arguments:
       -h, --help                      print help message
       -m, --man                       print complete documentation
       -v, --verbose                   use verbose output

 Arguments to install transatlasdb on MySQL
       -u, --username <string>         specify MySQL username (default: root)
       -p, --password <string>         specify MySQL password
       -d, --databasename <string>     specify DatabaseName (default: transatlasdb)

 Arguments to install transatlasdb on FastBit
       -l, --location <directory>	specify FastBit directory (default: current working directory)
       -n, --fastbitname <directory>    specify FastBitName (default: transatlasfb)

 Function: store connection details to existing TransAtlasDB if connection details were lost or changed after installation.
 
 Example: #to test/retrieve connection details
	  connect-tad.pL
        
	  #store connection details to existing TransAtlasDB with mysql root password as 'password' and using default options
          connect-tad.pL -p password
					
	  #store connection details to existing TransAtlasDB with username:root, password:root, databasename:testmysql, fastbitname:testfastbit
          connect-tad.pL -u root -p root -d testmysql -n testfastbit

 Version: $ Date: 2016-10-25 13:19:08 (Tue, 25 Oct 2016) $

=head1 OPTIONS

=over 8

=item B<--help>

print a brief usage message and detailed explantion of options.

=item B<--man>

print the complete manual of the program.

=item B<--verbose>

use verbose output.


=item B<-u| --username>

specify MySQL username with access to the database, if other than 'root' (default: root). 

=item B<-p|--password>

specify MySQL password (required)

=item B<-d|--databasename>

specify MySQL databasename if other than 'transatlasdb' (default: transatlasdb)

=item B<-l|--location>

specify FastBit storage path if other than current working directory (default will be the current dirrectory)

=item B<-n|--fastbitname>

specify FastBit storage name if other than 'transatlasfb'(default: transatlasfb)

=back

=head1 DESCRIPTION

TransAtlasDB is a database management system for organization of gene expression
profiling from numerous amounts of RNAseq data.

TransAtlasDB toolkit comprises of a suite of Perl script for easy archival and 
retrival of transcriptome profiling and genetic variants.

TransAtlasDB requires all analysis be stored in a single folder location for 
successful processing.

Detailed documentation for TransAtlasDB should be viewed on https://modupeore.github.io/TransAtlasDB/.

=over

=item * B<invalid input>

If any of the files input contain invalid arguments or format, TransAtlasDB 
will terminate the program and the invalid input with the outputted. 
Users should manually examine this file and identify sources of error.

=back

=head2 INSTALLATION REQUIREMENTS

=over 

=item * B<FastBit>
FastBit is an open-source data processing library. It provides a SQL platform
to search and query compressed bitmap indexes.
More details can be viewed at https://sdm.lbl.gov/fastbit/


=item * B<MySQL>
MySQL is an open-source relational database management system.

=item * B<SAMtools>
SAMtools is a set of utilities for interacting with and post-processing short DNA sequence read alignments in the SAM, BAM and CRAM formats, written by Heng Li.

=back

--------------------------------------------------------------------------------

TransAtlasDB is free for academic, personal and non-profit use.

For questions or comments, please contact $ Author: Modupe Adetunji <amodupe@udel.edu> $.

=cut
