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

our $VERSION = '$ Version: 3 $';
our $DATE = '$ Date: 2017-05-01 10:32:00 (Mon, 01 May 2017) $';
our $AUTHOR= '$ Author:Modupe Adetunji <amodupe@udel.edu> $';

#--------------------------------------------------------------------------------

our ($verbose, $efile, $help, $man);
our ($sqlfile,$connect, $dbverdict, $schemaverdict, $root, $additional, $verdict, $found);
my ($dbname,$username,$password,$location,$fbname);
my ($sth,$dbh,$schema); #connect to database;
our @dbtables = qw|Sample Animal MapStats GeneStats Metadata  GenesFpkm IsoformsFpkm VarAnnotation VarResult VarSummary|;
#--------------------------------------------------------------------------------
sub printerr; #declare error routine
our ($ibis, $ardea) = fastbit_name(); #ibis and ardea location
our $default = DEFAULTS(); #default error contact
my $localhost = 'localhost';
processArguments(); #Process input

#creating or using databases
$dbh = mysql_create($dbname, $username, $password); #connect to mysql to create database
`which ardea` or pod2usage("ERROR:\t TransAtlasDB requires the nosql platform => FastBit.\n\t Can not find fastbit executable 'ardea'. Download fastbit software and add to PATH.");
`which ibis` or pod2usage("ERROR:\t TransAtlasDB requires the nosql platform => FastBit.\n\t Can not find fastbit query 'ibis'. Download fastbit software and add to PATH");
$verbose and printerr "NOTICE:\t Using SCHEMA $dbname\n";
$sth = $dbh-> prepare("show databases"); $sth->execute;
my %HashDB = ();
while (my $row = $sth->fetchrow_array()){ $HashDB{$row} = $row; }
$sth->finish(); 
unless (exists $HashDB{$dbname}){$dbverdict = 1;} else { undef $dbverdict; }
if ($dbverdict) {
  $schema = "CREATE SCHEMA IF NOT EXISTS $dbname";
  $sth = $dbh->prepare($schema);
  $sth->execute() or die (qq(ERROR:\t Can't create database, make sure user has create schema  priviledges or use an existing database.));
  $verbose and printerr "EXECUTED: Created SCHEMA $dbname\n";
}

#using database created or existing database
$dbh->disconnect();
$dbh = mysql($dbname, $username, $password); #connect to mysql
#Check if tables already exist in database
SCHEMA();
printerr "JOB:\t MySQL = $dbname and NoSQL = $fbname creation\n";
if ($schemaverdict) { # if tables are in the database
  print "\nWARNING: Relational Database has requisite tables with content\n";
  print "\t Do you still want to recreate database? (Y/N): ";
  chomp ($verdict = lc (<>));
  print "\n";
} else { $verdict = "yes"; }
if ($verdict =~ /^y/) { #Import schema to mysql
  open (SQL, "$sqlfile") or die "ERROR:\t Can't open file schema file for reading, contact $AUTHOR\n";
  while (my $sqlStatement = <SQL>) {
    unless ($sqlStatement =~ /^-/){
      $sth = $dbh->prepare($sqlStatement)
        or die (qq(FAILED:\t Can not prepare $sqlStatement));
      $sth->execute()
        or die qq(FAILED:\t Can not execute $sqlStatement);
      $verbose and printerr "EXECUTED: $sqlStatement\n";
    }
  }
} elsif ($verdict =~ /^n/) {
  $verbose and printerr "NOTICE:\t Skipping (re)-creation of MySQL tables\n";
} else { die "ERROR:\t Response not provided\n"; }
$sth->finish();
$dbh->disconnect();

#create FastBit path on connection details
our $ffastbit = fastbit($location, $fbname);
#check if ibis and ardea can be found
`mkdir -p $ffastbit && chmod 777 $ffastbit`;
my $check = `ls $ffastbit`;
$verdict = "no";
if (length $check > 0){
	print "\nWARNING: FastBit already exists with content\n";
  print "\t Do you still want to recreate FastBit folder (Y/N): ";
  chomp ($verdict = lc (<>));
  print "\n";
} else { $verdict = "clean"; }
unless ($verdict =~ /clean/){
	if ($verdict =~ /^y/) {
	`rm -rf $ffastbit/*`;
	$verbose and printerr "NOTICE:\t Removed all data in existing FastBit folder\n";
	} elsif ($verdict =~ /^n/) {
	  $verbose and printerr "NOTICE:\t Skipping removal of initial data in FastBit folder\n";
	} else { die "ERROR:\t Response not provided\n"; }
}

$verbose and printerr "EXECUTED: Created Fastbit folder $ffastbit\n"; 

#output 
printerr "-----------------------------------------------------------------\n";
printerr ("NOTICE:\t Successful creation of MySQL database ==> \"$dbname\"\n");
printerr ("NOTICE:\t Successful creation of FastBit folder ==> \"".$ffastbit."\"\n");
if ($additional) { printerr $additional; };
printerr ("NOTICE:\t Summary in log file $efile\n");
printerr "-----------------------------------------------------------------\n";
print LOG "TransAtlasDB Completed:\t", scalar(localtime),"\n";
close (LOG);
#--------------------------------------------------------------------------------

sub processArguments {
	my @commandline = @ARGV;
	if ($> != 0) { pod2usage ("ERROR:\t TranAtlasDB requires root priviledges to proceed with installation.\n\t Provide root access by using \t'sudo perl $0 @commandline'") };
  GetOptions('verbose|v'=>\$verbose, 'help|h'=>\$help, 'man|m'=>\$man, 'databasename|d=s'=>\$dbname,
		'username|u=s'=>\$username, 'password|p=s'=>\$password, 'location|l=s'=>\$location,
		'fastbitname|n=s'=>\$fbname ) or pod2usage ();

  $help and pod2usage (-verbose=>1, -exitval=>1, -output=>\*STDOUT);
  $man and pod2usage (-verbose=>2, -exitval=>1, -output=>\*STDOUT);  
  pod2usage(-msg=>"Error: Required argument -p (MySQL password) not provided.") if (!$password);

  #set defaults
  $verbose ||=0;
  my $get = dirname(abs_path $0); #get source path
  $dbname = "transatlasdb" if (! $dbname);
  $fbname = "transatlasfb" if (! $fbname);
  $username = "root" if (! $username);
  if (! $location) {$location = $get;}

  #setup log file
    #setup log file
	$efile = @{ open_unique("db.tad_status.log") }[1];
	open(LOG, ">>", $efile) or die "\nERROR:\t cannot write LOG information to log file $efile $!\n";
  print LOG "TransAtlasDB Version:\t",$VERSION,"\n";
  print LOG "TransAtlasDB Information:\tFor questions, comments, documentation, bug reports and program update, please visit $default \n";
  print LOG "TransAtlasDB Command:\t $0 @commandline\n";
  print LOG "TransAtlasDB Started:\t", scalar(localtime),"\n";
  $sqlfile = "$get/schema/\.transatlasdb-ddl.sql";
  open(CONNECT, ">$get/\.connect.txt"); 
  my $connectcontent = "MySQL\n  username $username\n  password $password\n  databasename $dbname\nFastBit\n  path $location\n  foldername $fbname\n  ibis $ibis\n  ardea $ardea";
  print CONNECT $connectcontent; close (CONNECT);
  printerr "NOTICE:\t Establishing the TransAtlasDB web interface\n";
	print "\t Do you want to configure the web application (Y/N): ";
	undef $verdict; chomp ($verdict = lc(<>)); print "\n";
	if ($verdict =~ /^y/) {
		$verdict = "conf";
	  `which apachectl` or (printerr "ERROR:\t TransAtlasDB web requires Apache.\n\t Can not find Apache. Download Apache to use the web interface." and $verdict = "dont");
	  `which php` or (printerr "ERROR:\t TransAtlasDB web requires PHP scripting languange.\n\t Can not find PHP. Download PHP and configure to mysql inorder to use the web interface." and $verdict = "dont");
		if ($verdict =~ /conf/){
			if (`uname` =~ /linux/i){ $root = '/var/www/html/'; }
			elsif (`uname` =~ /darwin/i) { $root = '/Library/WebServer/Documents/'; }
			else { $root = $get; }
			print " Specify apache location, if other than '$root', else press enter : ";
			undef $verdict; chomp ($verdict = (<>)); print "\n"; 
			if ($verdict) {
				$verdict =~ s/\s+$//g; 
				if (-d $verdict) { $root = $verdict; $localhost = '<web_server_url>'; $verdict = "config"; }
				else { printerr "ERROR: Directory $verdict can not be found, Web Interface not configured\n"; }
			} else { $verdict = "config"; }
			if ($verdict =~ /config/) {
				`tar -xzf $get/.web.tgz -C $root`;
				open(CONFIG, ">$root/web/config.php");
				print CONFIG "<?php
  define('DB_SERVER', 'localhost');
  define('DB_USERNAME', '$username');
  define('DB_PASSWORD', '$password');
  define('DB_DATABASE', '$dbname');
  \$db_conn = mysqli_connect(DB_SERVER,DB_USERNAME,DB_PASSWORD,DB_DATABASE);
  \$basepath = '$get';
?>
				";
				close (CONFIG);
			} # end if config

		} #end if conf...
		if (-e "$root/web/config.php") {
			$root =~ s/\/$//g;
			$additional = "NOTICE:\t Successful creation of Web Interface ==> \"".$root."/web\"\n\t View web interface at your 'http://$localhost/web'\n";
		} #print completed statement, if successful.
		
	} elsif ($verdict) {
		printerr "NOTICE:\t Moving on, Web Interface not configured\n";
	} else {
		printerr "NOTICE:\t Response not provided, Web Interface not configured\n";
	}
}

sub SCHEMA {
  $sth = $dbh-> prepare("show tables"); $sth->execute;
  my %HashSchema = ();
  while (my $row = $sth->fetchrow_array()){
    $HashSchema{$row} = 1;
  }
  $sth->finish();
  foreach (@dbtables){
   if (exists $HashSchema{$_}){
      $schemaverdict = 1;
    } else { undef $schemaverdict; }
  }
}

#--------------------------------------------------------------------------------

=head1 SYNOPSIS

 INSTALL-tad.pL [arguments] -p <MySQLpassword>

 Optional arguments:
       -h, --help                      print help message
       -m, --man                       print complete documentation
       -v, --verbose                   use verbose output

 Arguments to install transatlasdb on MySQL
       -u, --username <string>         specify MySQL username (default: root)
       -p, --password <string>         specify MySQL password
       -d, --databasename <string>     specify DatabaseName (default: transatlasdb)

 Arguments to install transatlasdb on FastBit
       -l, --location <directory>	specify FastBit directory (default: source directory)
       -n, --fastbitname <directory>    specify FastBitName (default: transatlasfb)

 Function: create the TransAtlasDB tables in MySQL and FastBit location on local disk
 
 Example: #create TransAtlasDB with mysql root password as 'password' and using default options
          INSTALL-tad.pL -p password
        
          #create TransAtlasDB database with username:root, password:root, databasename:testmysql, fastbitname:testfastbit
          INSTALL-tad.pL -u root -p root -d testmysql -n testfastbit


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

specify MySQL username with 'GRANT ALL' priviledge, if other than 'root' (default: root). 

=item B<-p|--password>

specify MySQL password (required)

=item B<-d|--databasename>

specify MySQL databasename if other than 'transatlasdb' (default: transatlasdb)

=item B<-l|--location>

specify FastBit storage path if other than source script directory (default will be the source directory)

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

=over 8

=item * B<invalid input>

If any of the files input contain invalid arguments or format, TransAtlasDB 
will terminate the program and the invalid input with the outputted. 
Users should manually examine this file and identify sources of error.

=back

=head2 Sample Tab-delimited file

A sample tab-delimited file contains one sample per line, with the fields being sample name,
derived from, organism, organism part, sample description, first name, middle initial,
last name, organization. The 1st four fields (sample name, derived from, organism, organism part)
are required, while the other five fields may contain optional details in regards to the sample.
The 'sample name' must be a word and can be alphanumeric. An example is shown below.

  Sample Name	Derived from	Organism	Organism Part	Sample description	Organization
  GGA_UD_1004	GGA_UD_1004	Gallus gallus	Pituitary gland	21 day male Ross 708	University of Delaware
  GGA_UD_1014	GGA_UD_1014	Gallus gallus	Pituitary gland	21 day male Ross 708	University of Delaware

=head2 Directory/Folder structure

A sample directory structure contains all the files required for successful utilization
of TransAtlasDB, such as the mapping file outputs from either the TopHat2 or
HISAT2 software; expression file outputs from either the Cufflinks or StringTie software;
variant file from any bioinformatics variant analysis package
such as GATK, SAMtools, and (optional) variant annotation results from ANNOVAR 
or Ensembl VEP in tab-delimited format having suffix '.multianno.txt' and '.vep.txt' 
respectively.
The sample directory must be named the same 'sample_name' as with it's corresponding 'sample_name'
in the sample information previously imported.

=over 8

=item * B<TopHat2 and Cufflinks directory structure>
The default naming scheme from the above software are required.
The sub_folders <tophat_folder>,  <cufflinks_folder>, <variant_folder> are optional.
All files pertaining to such 'sample_name' must be in the same folder.
An example of TopHat and Cufflinks results directory is shown below:

	/sample_name/
	/sample_name/<tophat_folder>/
	/sample_name/<tophat_folder>/accepted_hits.bam
	/sample_name/<tophat_folder>/align_summary.txt
	/sample_name/<tophat_folder>/deletions.bed
	/sample_name/<tophat_folder>/insertions.bed
	/sample_name/<tophat_folder>/junctions.bed
	/sample_name/<cufflinks_folder>/
	/sample_name/<cufflinks_folder>/genes.fpkm_tracking
	/sample_name/<cufflinks_folder>/transcripts.gtf
	/sample_name/<variant_folder>/
	/sample_name/<variant_folder>/<filename>.vcf
	/sample_name/<variant_folder>/<filename>.multianno.txt
	/sample_name/<variant_folder>/<filename>.vep.txt
	
=item * B<HISAT2 and StringTie directory structure>
The required files from HISAT2 are the SAM mapping file (suffix = '.sam') and the
alignment summary details. The alignment summary is generated as a standard
output, which should be stored in a file named 'align_summary.txt'.
The required file from StringTie is the transcripts file with suffix = '.gtf').
The sub_folders <hisat_folder>,  <stringtie_folder>, <variant_folder> are optional.
All files pertaining to such 'sample_name' must be in the same folder.
An example of HiSAT2 and Stringtie results directory is shown below:

	/sample_name/
	/sample_name/<hisat_folder>/
	/sample_name/<hisat_folder>/align_summary.txt
	/sample_name/<hisat_folder>/<filename>.sam
	/sample_name/<stringtie_folder>/
	/sample_name/<stringtie_folder>/<filename>.gtf
	/sample_name/<variant_folder>/
	/sample_name/<variant_folder>/<filename>.vcf
	/sample_name/<variant_folder>/<filename>.multianno.txt
	/sample_name/<variant_folder>/<filename>.vep.txt

=back

=head2 Variant file format (VCF)

A sample variant file contains one variant per line, with the fields being chr,
start, end, reference allele, observed allele, other information. The other
information can be anything (for example, it may contain sample identifiers for
the corresponding variant.) An example is shown below:

        16      49303427        49303427        C       T       rs2066844       R702W (NOD2)
        16      49314041        49314041        G       C       rs2066845       G908R (NOD2)
        16      49321279        49321279        -       C       rs2066847       c.3016_3017insC (NOD2)
        16      49290897        49290897        C       T       rs9999999       intronic (NOD2)
        16      49288500        49288500        A       T       rs8888888       intergenic (NOD2)
        16      49288552        49288552        T       -       rs7777777       UTR5 (NOD2)
        18      56190256        56190256        C       T       rs2229616       V103I (MC4R)
				
TransAtlasDB accepts variants file from GATK and SAMtools (BCFtools)

=over 8

=back

--------------------------------------------------------------------------------

TransAtlasDB is free for academic, personal and non-profit use.

For questions or comments, please contact $ Author: Modupe Adetunji <amodupe@udel.edu> $.

=cut
