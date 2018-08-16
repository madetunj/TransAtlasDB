#!/usr/bin/env perl
use warnings;
use strict;
use Pod::Usage;
use Getopt::Long;
use File::Spec;
use File::Basename;
use Cwd qw(abs_path);
use lib dirname(abs_path $0) . '/lib';
use CC::Create;
use CC::Parse;
use Term::ANSIColor;

our $VERSION = '$ Version: 3 $';
our $DATE = '$ Date: 2017-05-05 05:14:00 (Fri, 05 May 2017) $';
our $AUTHOR= '$ Author:Modupe Adetunji <amodupe@udel.edu> $';

#--------------------------------------------------------------------------------
our ($connect, $efile, $help, $man, $nosql);
our (%MAINMENU, $verdict);
my $choice = 0;
my ($dbh, $sth, $fastbit);
#date
my $date = `date +%Y-%m-%d`;
my ($opa, $opb, $opc, $opd,$ope, $opf, $opg, $opj);
#--------------------------------------------------------------------------------
OPTIONS();
our ($ibis, $ardea) = fastbit_name(); #ibis and ardea location
our $default = DEFAULTS(); #default error contact
processArguments(); #Process input

my %all_details = %{connection($connect, $default)}; #get connection details
if (length($ibis) < 1){ ($ibis, $ardea) = ($all_details{'FastBit-ibis'}, $all_details{'FastBit-ardea'}); } #alternative for ibis and ardea location 

print "\tWELCOME TO TRANSATLASDB INTERACTIVE MODULE\n";
my $count =0;
MAINMENU:
while ($choice < 1){
	$verdict = undef;
	#process command line options
	if ($opa) { $choice = 1; $verdict = "a"; undef $opa; }
	if ($opb) { $choice = 1; $verdict = "b"; undef $opb; }
	if ($opc) { $choice = 1; $verdict = "c"; undef $opc; }
	if ($opd) { $choice = 1; $verdict = "d"; undef $opd; }
	if ($ope) { $choice = 1; $verdict = "e"; undef $ope; }
	if ($opf) { $choice = 1; $verdict = "f"; undef $opf; }
	if ($opg) { $choice = 1; $verdict = "g"; undef $opg; }
	if ($opj) { $choice = 1; $verdict = "h"; undef $opj; }

	#$verdict = "a" if ($opa); undef $opa; 
	#$verdict = "b" if ($opb); undef $opb;
	#$verdict = "c" if ($opc); undef $opc;
	#$verdict = "d" if ($opd); undef $opd;
	#$verdict = "e" if ($ope); undef $ope;
	#$verdict = "f" if ($opf); undef $opf;
	#$verdict = "g" if ($opg); undef $opg;
	#$verdict = "h" if ($opj); undef $opj;
	
	unless ($verdict) {
		print color ('bold');
		print "\n--------------------------------MAIN  MENU--------------------------------\n";
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print "Choose from the following options : \n";
		foreach (sort {$a cmp $b} keys %MAINMENU) { print "  ", uc($_),"\.  $MAINMENU{$_}\n";}
		print color('bold');
		print "--------------------------------------------------------------------------\n";
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print "\nSelect an option ? ";
		chomp ($verdict = lc (<>)); print "\n";
	}
	if ($verdict =~ /^[a-h]/){
		if ($verdict =~ /^exit/) { $choice = 1; next; }
		#$choice = 0;
		$dbh = mysql($all_details{'MySQL-databasename'}, $all_details{'MySQL-username'}, $all_details{'MySQL-password'}); #connect to mysql
		$fastbit = fastbit($all_details{'FastBit-path'}, $all_details{'FastBit-foldername'});  #connect to fastbit
		SUMMARY($dbh, $efile) if $verdict =~ /^a/;
		METADATA($dbh, $efile) if $verdict =~ /^b/;
		TRANSCRIPT($dbh,$efile) if $verdict =~ /^c/;
		AVERAGE($dbh,$efile,$fastbit,$nosql,$ibis) if $verdict =~ /^d/;
		GENEXP($dbh,$efile,$fastbit,$nosql,$ibis) if $verdict =~ /^e/;
		CHRVAR($dbh,$efile) if $verdict =~ /^f/;
		VARANNO($dbh,$fastbit,$efile,$nosql,$ibis) if $verdict =~ /^g/;
		CHRANNO($dbh,$fastbit,$efile,$nosql,$ibis) if $verdict =~ /^h/;
	} elsif ($verdict =~ /^x/) {
		$choice = 1;
	} elsif ($verdict =~ /^q/) {
		$choice = 1;
	} elsif ($verdict) {
		printerr "ERROR:\t Invalid Option\n";
	} else {
		printerr "NOTICE:\t No Option selected\n";
	}
}
#output: the end
printerr color('reset');
printerr "-----------------------------------------------------------------\n";
printerr ("SUCCESS: Clean exit from TransAtlasDB interaction module\n");
printerr ("NOTICE:\t Summary in log file $efile\n");
printerr "-----------------------------------------------------------------\n";
print LOG "TransAtlasDB Completed:\t", scalar(localtime),"\n";
close (LOG);

#--------------------------------------------------------------------------------

sub processArguments {
	my @commandline = @ARGV;
	GetOptions('help|h'=>\$help, 'man|m'=>\$man, 'a|summary'=>\$opa,'b|metadata'=>\$opb,
		 'c|transummary'=>\$opc, 'd|avgfpkm'=>\$opd, 'e|genexp'=>\$ope,'f|chrvar'=>\$opf,
		 'g|varanno'=>\$opg, 'j|chranno'=>\$opj) or pod2usage ();

  	$help and pod2usage (-verbose=>1, -exitval=>1, -output=>\*STDOUT);
  	$man and pod2usage (-verbose=>2, -exitval=>1, -output=>\*STDOUT);  
  
  	@ARGV==0 or pod2usage("Syntax error");

	#process command line options

  	my $get = dirname(abs_path $0); #get source path
  	$connect = $get.'/.connect.txt';
	#setup log file
  	$efile = @{ open_unique("db.tad_status.log") }[1];
	$nosql = @{ open_unique(".nosqlinteract.txt") }[1]; `rm -rf $nosql`;
  	open(LOG, ">>", $efile) or die "\nERROR:\t cannot write LOG information to log file $efile $!\n";
  	print LOG "TransAtlasDB Version:\t",$VERSION,"\n";
  	print LOG "TransAtlasDB Information:\tFor questions, comments, documentation, bug reports and program update, please visit $default \n";
  	print LOG "TransAtlasDB Command:\t $0 @commandline;\n";
  	print LOG "TransAtlasDB Started:\t", scalar(localtime),"\n";
}

sub OPTIONS {
	%MAINMENU = ( 
			a=>'Summary of samples in the database',
			b=>'Metadata details of samples', 
			c=>'Transcriptome analysis summary of samples',
			d=>'Average expression values of individual genes',
			e=>'Genes expression values across the samples',
			f=>'Chromosomal variant distribution',
			g=>'Gene-associated Variants with annotation information',
			h=>'Chromosomal region-associated Variants and annotation information',
			x=>'exit'
		);

}


#--------------------------------------------------------------------------------


=head1 SYNOPSIS

 tad-interact.pl <argument>

 Optional arguments:
        -h, --help                      print help message
        -m, --man                       print complete documentation

	Single Interactive Arguments 
	    -a, --summary               summary of samples in the database
            -b, --metadata              metadata details of samples
            -c, --transummary           transcriptome analysis summary of samples
            -d, --avgfpkm               average expression (fpkm) values of individual genes
            -e, --genexp                genes expression (fpkm) values across the samples
            -f, --chrvar                chromosomal variant distribution
            -g, --varanno               gene-associated variants with respective annotation information
       	    -j, --chranno               chromosomal region-associated variants and annotation information

 Function: interactive database module and guide to using tad-export.pl
 
 Example: #enter default interactive module
	  tad-interact.pl

	  #view only summary of samples in the database
          tad-interact.pl -a
	  tad-interact.pl -summary


 Version: $ Date: 2016-10-28 15:50:08 (Fri, 28 Oct 2016) $

=head1 OPTIONS

=over 8

=item B<--help>

print a brief usage message and detailed explantion of options.

=item B<--man>

print the complete manual of the program.

=item B<--summary>

provides summary tables of all the samples in the database.

=item B<--metadata>

provides the sample information of all the samples in the database.

=item B<--transummary>

provides transcriptome analysis summary, this includes:
mapping information summary, variant information summary and
gene information summary of samples in the database.

=item B<--avgfpkm>

provides average expression (in fpkm or tpm) values of specified genes.

=item B<--genexp>

provides genes expression (in fpkm or tpm) values of specified genes across samples

=item B<--chrvar>

provides summary counts of the different variant types per chromosome for each sample.

=item B<--varanno>

provides gene-associated variants with respective annotation information.

=item B<--chranno>

provides chromosomal region-associated variants and (optional) annotation information.

=back

=head1 DESCRIPTION

TransAtlasDB is a database management system for organization of gene expression
profiling from numerous amounts of RNAseq data.

TransAtlasDB toolkit comprises of a suite of Perl script for easy archival and 
retrival of transcriptome profiling and genetic variants.

Detailed documentation for TransAtlasDB should be viewed on https://modupeore.github.io/TransAtlasDB/.

=over 8

=item * B<output format>

TransAtlasDB prints results as a table to the screen.
Results can be stored in a tab-delimited format or VCF file for variants.
The tab-delimited file is compartible with most text-editors or statistics package.
The VCF file is compartible with most text-editors or downstream analysis that accepts VCFs.

=item * B<invalid input>

If any of the files input contain invalid arguments or format, TransAtlasDB 
will terminate the program and the invalid input with the outputted. 
Users should manually examine this file and identify sources of error.

=back


--------------------------------------------------------------------------------

TransAtlasDB is free for academic, personal and non-profit use.

For questions or comments, please contact $ Author: Modupe Adetunji <amodupe@udel.edu> $.

=cut


