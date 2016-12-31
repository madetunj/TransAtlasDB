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

our $VERSION = '$ Version: 2 $';
our $DATE = '$ Date: 2016-10-28 14:40:00 (Fri, 28 Oct 2016) $';
our $AUTHOR= '$ Author:Modupe Adetunji <amodupe@udel.edu> $';

#--------------------------------------------------------------------------------

our ($verbose, $efile, $help, $man, $nosql, $transaction);
our ($metadata, $tab, $excel, $datadb, $gene, $variant, $all, $vep, $annovar, $delete); #command options
our ($file2consider,$connect); #connection and file details
my ($sth,$dbh,$schema); #connect to database;

our ($sheetid, %NAME, %ORGANIZATION);

#data2db options
our ($found);
our (@allgeninfo);
my ($str, $ann, $ref, $seq,$allstart, $allend) = (0,0,0,0,0,0); #for log file
my ($refgenome, $stranded, $sequences, $annotation, $annotationfile); #for annotation file
my $additional;
#genes import
our ($acceptedbam, $alignfile, $genesfile,$isoformsfile, $deletionsfile, $insertionsfile, $junctionsfile, $prepfile, $logfile, $variantfile, $vepfile, $annofile);
our ($total, $mapped, $unmapped, $deletions, $insertions, $junctions, $genes, $isoforms,$prep);
#variant import
our ( %VCFhash, %DBSNP, %extra, %VEPhash, %ANNOhash );
our ($varianttool, $verd, $variantclass);
our ($itsnp,$itindel,$itvariants) = (0,0,0);

#nosql append
my (@nosqlrow, $showcase);
#date
my $date = `date +%Y-%m-%d`;

#--------------------------------------------------------------------------------

sub printerr; #declare error routine
our $default = DEFAULTS(); #default error contact
processArguments(); #Process input

my %all_details = %{connection($connect, $default)}; #get connection details

#PROCESSING METADATA
if ($metadata){
	$dbh = mysql($all_details{'MySQL-databasename'}, $all_details{'MySQL-username'}, $all_details{'MySQL-password'}); #connect to mysql
  	if ($tab) { #unix tab delimited file
    		printerr "JOB:\t Importing Sample Information from tab-delimited file => $file2consider\n"; #status
	    	my %filecontent = %{ tabcontent($file2consider) }; #get content from tab-delimited file
    		foreach my $row (sort keys %filecontent){
	      		if (exists $filecontent{$row}{'sample name'}) { #sample name
				my $sheetid = "$filecontent{$row}{'first name'} $filecontent{$row}{'middle initial'} $filecontent{$row}{'last name'}"; #scientist name
				if (length $sheetid > 3) { #Person Name 
	  				$sth = $dbh->prepare("select personid from Person where personid = '$sheetid'"); $sth->execute(); $found = $sth->fetch();
		  			unless ($found) { # if person is not in the database
		    				$sth = $dbh->prepare("insert into Person (personid, firstname, lastname, middleinitial) values (?,?,?,?)");
	    					$sth->execute($sheetid, $filecontent{$row}{'first name'}, $filecontent{$row}{'last name'}, $filecontent{$row}{'middle initial'}) or die "\nERROR:\t Complication in Person table\n";
					}
					$NAME{$sheetid} = $sheetid;
				} else {
					undef $sheetid;
				}
				$sheetid = $filecontent{$row}{'organization name'}; #organization name
				if ($sheetid) { #Organization Name
					$sth = $dbh->prepare("select organizationname from Organization where organizationname = '$sheetid'"); $sth->execute(); $found = $sth->fetch();
					unless ($found) { # if person is not in the database
						$sth = $dbh->prepare("insert into Organization (organizationname) values ('$sheetid')");
						$sth->execute() or die "\nERROR:\t Complication in Organization table\n";
					}
					$ORGANIZATION{$sheetid} = $sheetid;
				} else {
					undef $sheetid;
				}
				if (exists $filecontent{$row}{'organism'}) { #organism name
					$sheetid = $filecontent{$row}{'organism'};
					$sth = $dbh->prepare("select organism from Organism where organism = '$sheetid'"); $sth->execute(); $found =$sth->fetch();
					unless ($found) { # if is not in the database
						$sth = $dbh->prepare("insert into Organism (organism) values ('$sheetid')");
						$sth->execute() or die "\nERROR:\t Complication in Organism table\n";
					}
					undef $sheetid;
				} else {
					die "\nFAILED:\t Error in tab-delimited file \"$file2consider\".\n\tCheck => ROW: $row, COLUMN: \"Organism\"\n";
				} #end if for animal info
				if (exists $filecontent{$row}{'derived from'}) { #animal id
					$sheetid = uc($filecontent{$row}{'derived from'});
					$sth = $dbh->prepare("select animalid from Animal where animalid = '$sheetid'"); $sth->execute(); $found =$sth->fetch();
					unless ($found) {
						printerr "NOTICE:\t Importing $sheetid to Animal table\n";
						$sth = $dbh->prepare("insert into Animal (animalid, organism) values (?,?)");
						$sth->execute($sheetid, $filecontent{$row}{'organism'} ) or die "\nERROR:\t Complication in Animal table\n";
					} else {
						$verbose and printerr "Duplicate: AnimalID '$sheetid' already exists in Animal table. Moving on\n";
					}
					undef $sheetid;
				} else {
					die "\nFAILED:\t Error in tab-delimited file \"$file2consider\".\n\tCheck => ROW: $row, COLUMN: \"Derived From\"\n";
				}
				if (exists $filecontent{$row}{'organism part'}) { #organism part / tissue
					$sheetid  = $filecontent{$row}{'organism part'};
					$sth = $dbh->prepare("select tissue from Tissue where tissue = '$sheetid'"); $sth->execute(); $found = $sth->fetch();
					unless ($found) { # if is not in the database
						$sth = $dbh->prepare("insert into Tissue (tissue) values ('$sheetid')");
						$sth->execute() or die "\nERROR:\t Complication in Tissue table\n";
					}
					undef $sheetid;
				}
				$sheetid  = uc($filecontent{$row}{'sample name'}); #Sample Table
				$sth = $dbh->prepare("select sampleid from Sample where sampleid = '$sheetid'"); $sth->execute(); $found =$sth->fetch();
				unless ($found) { # if sample is not in the database
					printerr "NOTICE:\t Importing $sheetid to Sample table\n";
					$sth = $dbh->prepare("insert into Sample (sampleid, tissue, derivedfrom, description,date) values (?,?,?,?,?)");
					$sth->execute($sheetid, $filecontent{$row}{'organism part'}, $filecontent{$row}{'derived from'}, $filecontent{$row}{'sample description'},$date) or die "\nERROR:\t Complication in Sample table\n";
				} else {
					printerr "Duplicate: SampleID '$sheetid' already exists in Sample table. Moving on.\n";
					printerr "Optional: To delete $sheetid ; Execute: tad-import.pl -delete $sheetid\n";
				}
			} else {
				pod2usage("\nFAILED:\t Error in tab-delimited file \"$file2consider\".\n\tCheck => ROW: $row, COLUMN: \"Sample Name\"");
			} #end of if sample name is real
		} #end of foreach file content
	} #end of tab unix option
	else { #import faang excel sheet
		my ($sheetid, @excelcontent, %columnpos); #metadata excel
		printerr "JOB:\t Importing Sample Information from excel file => $file2consider\n"; #status    
    		@excelcontent = excelcontent($file2consider); #get excel content
		for (@excelcontent){s/%%//g;}
		foreach (@excelcontent) {
			my @array = split "\n";
			my @header = split('\?abc\?',lc($array[1]));
			if ($array[0] =~ /person/) { #Working with Person Sheet;
				undef %columnpos; #undefined column position
				if ($#array > 1) {
					foreach my $no (0..$#header) {
						$columnpos{$header[$no]} = $no;
					}#end foreach : put header info into a Dictionary
					foreach my $ne (2..$#array) {
						my @value = split('\?abc\?', $array[$ne]);
						if (length $value[0] > 1) {
							$sheetid  = "$value[$columnpos{'person first name'}] $value[$columnpos{'person initials'}] $value[$columnpos{'person last name'}]";
							$sth = $dbh->prepare("select personid from Person where personid = '$sheetid'"); $sth->execute(); $found = $sth->fetch();
							unless ($found) { # if person is not in the database
								$sth = $dbh->prepare("insert into Person (personid, lastname, middleinitial, firstname, email, role) values (?,?,?,?,?,?)");
								$sth->execute($sheetid, $value[$columnpos{'person last name'}], $value[$columnpos{'person initials'}], $value[$columnpos{'person first name'}], $value[$columnpos{'person email'}], $value[$columnpos{'person role'}]) or die "\nERROR:\t Complication in Person table\n";
							}
							$NAME{$sheetid} = $sheetid;
						} else { #end if : insert into database
							undef $sheetid;
						} #end else table has no information
					} #end foreach : getting information into the database and into dictionary
				} else { #end if : if there is content in thetable
					undef $sheetid; #make sure sheetid is undefined if there is no content in the sheet
				}
			}
			if ($array[0] =~ /organization/)  { #Working with Organization Sheet;
				undef %columnpos; #undefine column position
				if ($#array > 1) {
					foreach my $no (0..$#header) {
						$columnpos{$header[$no]} = $no;
					}#end foreach : put header info into a Dictionary
					foreach my $ne (2..$#array) {
						my @value = split('\?abc\?', $array[$ne]);
						if (length $value[0] > 1) {
							$sheetid  = $value[$columnpos{'organization name'}];
							$sth = $dbh->prepare("select organizationname from Organization where organizationname = '$sheetid'"); $sth->execute(); $found = $sth->fetch();
							unless ($found) { # if organization is not in the database
								$sth = $dbh->prepare("insert into Organization (organizationname,address, URL, role) values (?,?,?,?)");
								$sth->execute($sheetid, $value[$columnpos{'organization address'}], $value[$columnpos{'organization uri'}], $value[$columnpos{'organization role'}]) or die "\nERROR:\t Complication in Organization table\n";
							} 
							$ORGANIZATION{$sheetid} = $sheetid;
						} else { #end if : insert into database
							undef $sheetid;
						} #end else table has no information
					} #end foreach : getting information into the database and into dictionary
				} else { #end if : if there is content in thetable
					undef $sheetid; #make sure sheetid is undefined if there is no content in the sheet
				} #end else
			} #end if organization
			if ($array[0] =~ /animal/)  { #Working with Animal Sheet;
				my %ANIMAL = (material=>'Material', organism => 'Organism', sex => 'Sex', breed => 'Breed');
				undef %columnpos; #undefine column position
				if ($#array > 1) {
					foreach my $no (0..$#header) {
						if ($header[$no] =~ /[material|organism|sex|breed|health]/) {
							$columnpos{$header[$no]} = $no;
							$no = $no+2;
						} elsif ($header[$no] =~ /[birth|placental|pregnancy]/) {
							$columnpos{$header[$no]} = $no;
							$no = $no+2;
						} else {
							$columnpos{$header[$no]} = $no;
						}
					}	#end foreach : put header info into a Dictionary
					foreach my $ne (2..$#array) {
						my @value = split('\?abc\?', $array[$ne]);
						if (length $value[0] > 1) {
							foreach my $id (sort keys %ANIMAL) { 
								if (length $value[$columnpos{$id}] > 1) {
									$sheetid  = "$value[$columnpos{$id}]";
									my $loc = $columnpos{$id};
									$sth = $dbh->prepare("select $id from $ANIMAL{$id} where $id = '$sheetid'"); $sth->execute(); $found = $sth->fetch();
									unless ($found) { # if material is not in the database
										$sth = $dbh->prepare("insert into $ANIMAL{$id} ($id, termref, termid) values (?,?,?)");
										$sth->execute($sheetid, $value[$loc+1], $value[$loc+2] ) or die "\nERROR:\t Complication in $ANIMAL{$id} table\n";
									}
								}
							}
							if (length $value[$columnpos{'health status'}] > 1) {
								$sheetid  = "$value[$columnpos{'health status'}]";
								my $loc = $columnpos{'health status'};
								$sth = $dbh->prepare("select health from HealthStatus where health = '$sheetid'"); $sth->execute(); $found = $sth->fetch();
								unless ($found) { # if material is not in the database
									$sth = $dbh->prepare("insert into HealthStatus (health,termref, termid) values (?,?,?)");
									$sth->execute($sheetid, $value[$loc+1], $value[$loc+2] ) or die "\nERROR:\t Complication in HealthStatus table\n";
								}
							}
							$sheetid  = uc($value[$columnpos{'sample name'}]); #Animal Table
							$sth = $dbh->prepare("select animalid from Animal where animalid = '$sheetid'"); $sth->execute(); $found =$sth->fetch();
							unless ($found) { # if animal is not in the database
								printerr "NOTICE:\t Importing $sheetid to Animal table\n";
								$sth = $dbh->prepare("insert into Animal (animalid, project, material, organism, sex, health, breed, description) values (?,?,?,?,?,?,?,?)");
								$sth->execute($sheetid, $value[$columnpos{'project'}], $value[$columnpos{'material'}], $value[$columnpos{'organism'}], $value[$columnpos{'sex'}], $value[$columnpos{'health status'}], $value[$columnpos{'breed'}],$value[$columnpos{'sample description'}]) or die "\nERROR:\t Complication in Animal table\n";
							} else {
								$verbose and printerr "Duplicate: AnimalID '$sheetid' already exists in Animal table. Moving on\n";
							}
							$sth = $dbh->prepare("select animalid from AnimalStats where animalid = '$sheetid'"); $sth->execute(); $found =$sth->fetch();
							unless ($found) { # if animalstats is not in the database
								my ($loc, $birthdate, $birthlocation, $birthloclatitude, $birthloclongitude, $birthweight, $placentaweight, $pregnancylength) = ();
								if ($value[$columnpos{'birth date'}]) { $birthdate = "$value[$columnpos{'birth date'}] \($value[$columnpos{'birth date'}+1]\)"; }
								if ($value[$columnpos{'birth location'}]) { $birthlocation = "$value[$columnpos{'birth location'}] \($value[$columnpos{'birth location'}+1]\)"; }
								if ($value[$columnpos{'birth location latitude'}]) { $birthloclatitude = "$value[$columnpos{'birth location latitude'}] \($value[$columnpos{'birth location latitude'}+1]\)"; }
								if ($value[$columnpos{'birth location longitude'}]) { $birthloclongitude = "$value[$columnpos{'birth location longitude'}] \($value[$columnpos{'birth location longitude'}+1]\)"; }
								if ($value[$columnpos{'birth weight'}]) { $birthweight = "$value[$columnpos{'birth weight'}] \($value[$columnpos{'birth weight'}+1]\)"; }
								if ($value[$columnpos{'placental weight'}]) { $placentaweight = "$value[$columnpos{'placental weight'}] \($value[$columnpos{'placental weight'}+1]\)"; }
								if ($value[$columnpos{'pregnancy length'}]) { $pregnancylength = "$value[$columnpos{'pregnancy length'}] \($value[$columnpos{'pregnancy length'}+1]\)"; }
								$sth = $dbh->prepare("insert into AnimalStats (animalid, birthdate, birthlocation, birthloclatitude, birthloclongitude, birthweight, placentalweight, pregnancylength, deliveryease, deliverytiming, pedigree) values (?,?,?,?,?,?,?,?,?,?,?)");
								$sth->execute($sheetid, $birthdate, $birthlocation, $birthloclatitude, $birthloclongitude, $birthweight, $placentaweight, $pregnancylength, $value[$columnpos{'delivery ease'}], $value[$columnpos{'delivery timing'}], $value[$columnpos{'pedigree'}]) or die "\nERROR:\t Complication in AnimalStats table\n";
							} else {
								$verbose and printerr "Duplicate: AnimalID '$sheetid' already exists in AnimalStats table. Moving on\n";
							}							
						} else { #end if : insert into database
							undef $sheetid;
						} #end else table has no information
					} #end foreach : getting information into the database
				} else { #end if : if there is content in thetable
					undef $sheetid; #make sure sheetid is undefined if there is no content in the sheet
				} #end else
			} #end if animal
			if ($array[0] =~ /specimen/)  { #Working with Specimen Sheet;
				undef %columnpos; #undefine column position
				if ($#array > 1) {
					foreach my $no (0..$#header) {
						if ($header[$no] =~ /[material|organism|health|developmental]/) {
							$columnpos{$header[$no]} = $no;
							$no = $no+2;
						} elsif ($header[$no] =~ /[date|animal age|number|volume|size|weight|gestational]/) {
							$columnpos{$header[$no]} = $no;
							$no = $no+2;
						} else {
							$columnpos{$header[$no]} = $no;
						}
					}	#end foreach : put header info into a Dictionary
					foreach my $ne (2..$#array) { #each row
						my @value = split('\?abc\?', $array[$ne]);
						if (length $value[0] > 1) {
							if (length $value[$columnpos{'material'}] > 1) {
								$sheetid  = "$value[$columnpos{'material'}]";
								my $loc = $columnpos{'material'};
								$sth = $dbh->prepare("select material from Material where material = '$sheetid'"); $sth->execute(); $found = $sth->fetch();
								unless ($found) { # if material is not in the database
									$sth = $dbh->prepare("insert into Material (material,termref, termid) values (?,?,?)");
									$sth->execute($sheetid, $value[$loc+1], $value[$loc+2] ) or die "\nERROR:\t Complication in Material table\n";
								}
							}
							if (length $value[$columnpos{'organism part'}] > 1) {
								$sheetid  = "$value[$columnpos{'organism part'}]";
								my $loc = $columnpos{'organism part'};
								$sth = $dbh->prepare("select tissue from Tissue where tissue = '$sheetid'"); $sth->execute(); $found = $sth->fetch();
								unless ($found) { # if is not in the database
									$sth = $dbh->prepare("insert into Tissue (tissue,termref, termid) values (?,?,?)");
									$sth->execute($sheetid, $value[$loc+1], $value[$loc+2] ) or die "\nERROR:\t Complication in Tissue table\n";
								}
							}
							if (length $value[$columnpos{'developmental stage'}] > 1) {
								$sheetid  = "$value[$columnpos{'developmental stage'}]";
								my $loc = $columnpos{'developmental stage'};
								$sth = $dbh->prepare("select developmentalstage from DevelopmentalStage where developmentalstage = '$sheetid'"); $sth->execute(); $found = $sth->fetch();
								unless ($found) { # ifis not in the database
									$sth = $dbh->prepare("insert into DevelopmentalStage (developmentalstage,termref, termid) values (?,?,?)");
									$sth->execute($sheetid, $value[$loc+1], $value[$loc+2] ) or die "\nERROR:\t Complication in DevelopmentalStage table\n";
								}
							}
							if (length $value[$columnpos{'health status at collection'}] > 1) {
								$sheetid  = "$value[$columnpos{'health status at collection'}]";
								my $loc = $columnpos{'health status at collection'};
								$sth = $dbh->prepare("select health from HealthStatus where health = '$sheetid'"); $sth->execute(); $found = $sth->fetch();
								unless ($found) { # if is not in the database
									$sth = $dbh->prepare("insert into HealthStatus (health,termref, termid) values (?,?,?)");
									$sth->execute($sheetid, $value[$loc+1], $value[$loc+2] ) or die "\nERROR:\t Complication in HealthStatus table\n";
								}
							}
							$sheetid  = uc($value[$columnpos{'sample name'}]); #Sample Table
							$sth = $dbh->prepare("select sampleid from Sample where sampleid = '$sheetid'"); $sth->execute(); $found =$sth->fetch();
							unless ($found) { # if sample is not in the database
								printerr "NOTICE:\t Importing $sheetid to Sample table\n";
								$sth = $dbh->prepare("insert into Sample (sampleid, project, material, tissue, derivedfrom, availability, developmentalstage, health, description, date) values (?,?,?,?,?,?,?,?,?,?)");
								$sth->execute($sheetid, $value[$columnpos{'project'}], $value[$columnpos{'material'}], $value[$columnpos{'organism part'}], uc($value[$columnpos{'derived from'}]), $value[$columnpos{'availability'}], $value[$columnpos{'developmental stage'}], $value[$columnpos{'health status at collection'}],$value[$columnpos{'sample description'}], $date) or die "\nERROR:\t Complication in Sample table\n";
							} else {
								printerr "Duplicate: SampleID '$sheetid' already exists in Sample table. Moving on\n";
								printerr "Optional: To delete $sheetid ; Execute: tad-import.pl -delete $sheetid\n";
							}
							$sth = $dbh->prepare("select sampleid from SampleStats where sampleid = '$sheetid'"); $sth->execute(); $found =$sth->fetch();
							unless ($found) { # if samplestats is not in the database
								my ($specimendate, $agecollect, $noofpieces, $specimenvolume, $specimensize, $specimenweight, $gestage) = ();
								if ($value[$columnpos{'specimen collection date'}]) { $specimendate = "$value[$columnpos{'specimen collection date'}] \($value[$columnpos{'specimen collection date'}+1]\)"; }
								if ($value[$columnpos{'animal age at collection'}]) { $agecollect = "$value[$columnpos{'animal age at collection'}] \($value[$columnpos{'animal age at collection'}+1]\)"; }
								if ($value[$columnpos{'number of pieces'}]) { $noofpieces = "$value[$columnpos{'number of pieces'}] \($value[$columnpos{'number of pieces'}+1]\)"; }
								if ($value[$columnpos{'specimen volume'}]) { $specimenvolume = "$value[$columnpos{'pecimen volume'}] \($value[$columnpos{'pecimen volume'}+1]\)"; }
								if ($value[$columnpos{'specimen size'}]) { $specimensize = "$value[$columnpos{'specimen size'}] \($value[$columnpos{'specimen size'}+1]\)"; }
								if ($value[$columnpos{'specimen weight'}]) { $specimenweight = "$value[$columnpos{'specimen weight'}] \($value[$columnpos{'specimen weight'}+1]\)"; }
								if ($value[$columnpos{'gestational age at sample collection'}]) { $gestage = "$value[$columnpos{'gestational age at sample collection'}] \($value[$columnpos{'gestational age at sample collection'}+1]\)"; }
								$sth = $dbh->prepare("insert into SampleStats (sampleid, collectionprotocol, collectiondate, ageatcollection, fastedstatus, noofpieces, specimenvol, specimensize, specimenwgt, specimenpictureurl, gestationalage) values (?,?,?,?,?,?,?,?,?,?,?)");
								$sth->execute($sheetid, $value[$columnpos{'specimen collection protocol'}], $specimendate, $agecollect, $value[$columnpos{'fasted status'}], $noofpieces, $specimenvolume, $specimensize, $specimenweight, $value[$columnpos{'specimen picture url'}], $gestage) or die "\nERROR:\t Complication in SampleStats table\n";
							} else {
								$verbose and printerr "Duplicate: SampleID '$sheetid' already exists in SampleStats table. Moving on\n";
							}
							foreach (keys %NAME) {
								$sth = $dbh->prepare("select sampleid, personid from SamplePerson where sampleid = '$sheetid' and personid = '$_'"); $sth->execute(); $found =$sth->fetch();
								unless ($found) { # if sample-person is not in the database
									$sth = $dbh->prepare("insert into SamplePerson (sampleid, personid) values (?,?)");
									$sth->execute($sheetid, $_) or die "\nERROR:\t Complication in SamplePerson table\n";
								}
							}
							foreach (keys %ORGANIZATION) {
								$sth = $dbh->prepare("select sampleid, organizationname from SampleOrganization where sampleid = '$sheetid' and organizationname = '$_'"); $sth->execute(); $found =$sth->fetch();
								unless ($found) { # if sample-organization is not in the database
									$sth = $dbh->prepare("insert into SampleOrganization (sampleid, organizationname) values (?,?)");
									$sth->execute($sheetid, $_) or die "\nERROR:\t Complication in SampleOrganization table\n";
								}
							}
						} else { #end if : insert into database
							undef $sheetid;
						} #end else table has no information
					} #end foreach : getting information into the database
				} else { #end if : if there is content in thetable
					undef $sheetid; #make sure sheetid is undefined if there is no content in the sheet
				}#end else			
			} #end if specimen
		} #end foreach @excelcontent
  	} #end if excel
} #end if metadata

#PROCESSING DATA IMPORT
if ($datadb) {
	printerr "JOB:\t Importing Transcriptome analysis Information => $file2consider\n"; #status
  	if ($variant){
		printerr "TASK:\t Importing ONLY Variant Information => $file2consider\n"; #status
  	} elsif ($all) {
    		printerr "TASK:\t Importing BOTH Gene Expression profiling and Variant Information => $file2consider\n"; #status
  	} else {
    		printerr "TASK:\t Importing ONLY Gene Expression Profiling information => $file2consider\n"; #status
  	}
  	$dbh = mysql($all_details{"MySQL-databasename"}, $all_details{'MySQL-username'}, $all_details{'MySQL-password'}); #connect to mysql
  	my $dataid = (split("\/", $file2consider))[-1]; 
  	`find $file2consider` or pod2usage ("ERROR: Can not locate \"$file2consider\"");
  	opendir (DIR, $file2consider) or pod2usage ("Error: $file2consider is not a folder, please specify your sample location"); close (DIR);
  	my @foldercontent = split("\n", `find $file2consider`); #get details of the folder
  	$acceptedbam = (grep /accepted_hits.bam/, @foldercontent)[0];
  	$alignfile = (grep /align_summary.txt/, @foldercontent)[0];
  	$genesfile = (grep /genes.fpkm/, @foldercontent)[0];
  	$isoformsfile = (grep /isoforms.fpkm/, @foldercontent)[0];
  	$deletionsfile = (grep /deletions.bed/, @foldercontent)[0];
  	$insertionsfile = (grep /insertions.bed/, @foldercontent)[0];
  	$junctionsfile = (grep /junctions.bed/, @foldercontent)[0];
  	$prepfile = (grep /prep_reads.info/,@foldercontent)[0];
  	$logfile = (grep /logs\/run.log/, @foldercontent)[0];
  	$variantfile = (grep /.vcf$/, @foldercontent)[0]; 
  	$vepfile = (grep /.vep.txt$/, @foldercontent)[0];
  	$annofile = (grep /anno.txt$/, @foldercontent)[0];
 
  	$sth = $dbh->prepare("select sampleid from Sample where sampleid = '$dataid'"); $sth->execute(); $found = $sth->fetch();
  	if ($found) { # if sample is not in the database    
    		$sth = $dbh->prepare("select sampleid from MapStats where sampleid = '$dataid'"); $sth->execute(); $found = $sth->fetch();
    		unless ($found) { 
      			LOGFILE(); #parse logfile details
      			#open alignment summary file
      			if ($alignfile) {
        			open(ALIGN,"<", $alignfile) or die "\nFAILED:\t Can not open Alignment summary file '$alignfile'\n";
        			while (<ALIGN>){
          				chomp;
          				if (/Input/){my $line = $_; $line =~ /Input.*:\s+(\d+)$/;$total = $1;}
 			         	if (/Mapped/){my $line = $_; $line =~ /Mapped.*:\s+(\d+).*$/;$mapped = $1;}
        			} close ALIGN;
        			$unmapped = $total-$mapped;
        			$prep = `cat $prepfile`;
      			} else {die "\nFAILED:\t Can not find Alignment summary file '$alignfile'\n";}
      			#INSERT INTO DATABASE:
      			#MapStats table
      			printerr "NOTICE:\t Importing $dataid to MapStats table ..."; 
      			$sth = $dbh->prepare("insert into MapStats (sampleid, totalreads, mappedreads, unmappedreads, infoprepreads, date ) values (?,?,?,?,?,?)");
      			$sth ->execute($dataid, $total, $mapped, $unmapped, $prep, $date) or die "\nERROR:\t Complication in MapStats table, contact $AUTHOR\n";
      			printerr " Done\n";
      			#metadata table
      			printerr "NOTICE:\t Importing $dataid to Metadata table ...";
      			$sth = $dbh->prepare("insert into Metadata (sampleid, refgenome, annfile, stranded, sequencename ) values (?,?,?,?,?)");
      			$sth ->execute($dataid, $refgenome, $annotationfile, $stranded,$sequences) or die "\nERROR:\t Complication in Metadata table, contact $AUTHOR\n";
      			printerr " Done\n";
      
		     	#toggle options
      			unless ($variant) {
        			GENE_INFO($dataid);
        			#FPKM tables
        			printerr "NOTICE:\t Importing $dataid - Genes to GenesFpkm table ...";
        			FPKM('GenesFpkm', $genesfile, $dataid); #GENES
        			printerr " Done\n";
        			printerr "NOTICE:\t Importing $dataid - Isoforms to IsoformsFpkm table ...";
        			FPKM('IsoformsFpkm', $isoformsfile, $dataid); #ISOFORMS
        			printerr " Done\n";
        			$sth = $dbh->prepare("update GeneStats set status = 'done' where sampleid = '$dataid'");
        			$sth ->execute() or die "\nERROR:\t Complication in GeneStats table, contact $AUTHOR\n";
        			if ($all){
          				printerr "NOTICE:\t Importing $dataid - Variants to VarResult table ...";
          				DBVARIANT($variantfile, $dataid);
          				printerr " Done\n";
          				#variant annotation specifications
          				if ($vep) {
            					printerr "TASK:\t Importing Variant annotation from VEP => $file2consider\n"; #status
  	    					printerr "NOTICE:\t Importing $dataid - Variant Annotation to VarAnno table ...";
            					VEPVARIANT($vepfile, $dataid); printerr " Done\n";
						NOSQL($dataid);
          				}
          				if ($annovar) {
            					printerr "TASK:\t Importing Variant annotation from ANNOVAR => $file2consider\n"; #status
  	    					printerr "NOTICE:\t Importing $dataid - Variant Annotation to VarAnno table ...";
            					ANNOVARIANT($annofile, $dataid); printerr " Done\n";
						NOSQL($dataid);
          				}
        			}
      			}
      			else { #variant option selected
		        	printerr "NOTICE:\t Importing $dataid - Variants to VarResult table ...";
			        DBVARIANT($variantfile, $dataid);
			        printerr " Done\n";
			        #variant annotation specifications
		        	if ($vep) {
					printerr "TASK:\t Importing Variant annotation from VEP => $file2consider\n"; #status
				        printerr "NOTICE:\t Importing $dataid - Variant Annotation to VarAnno table ...";
	          			VEPVARIANT($vepfile, $dataid); printerr " Done\n";
					NOSQL($dataid);
        			}
        			if ($annovar) {
          				printerr "TASK:\t Importing Variant annotation from ANNOVAR => $file2consider\n"; #status
			  		printerr "NOTICE:\t Importing $dataid - Variant Annotation to VarAnno table ...";
			          	ANNOVARIANT($annofile, $dataid); printerr " Done\n";
					NOSQL($dataid);
        			}
      			}
    		} else { #end unless found in MapStats table
      			printerr "NOTICE:\t $dataid already in MapStats table... Moving on \n";
						$additional .=  "Optional: To delete $dataid from MapStats table ; Execute: tad-import.pl -delete $dataid \n";
      			$sth = $dbh->prepare("select sampleid from Metadata where sampleid = '$dataid'"); $sth->execute(); $found = $sth->fetch();
	      		unless ($found) {
        			printerr "NOTICE:\t Importing $dataid to MapStats table ...";
 			        $sth = $dbh->prepare("insert into Metadata (sampleid,refgenome, annfile, stranded, sequencename ) values (?,?,?,?,?)");
	        		$sth ->execute($dataid, $refgenome, $annotationfile, $stranded,$sequences) or die "\nERROR:\t Complication in Metadata table\n";
        			printerr " Done\n";
      			} #end else found in MapStats table
      			#toggle options
	      		unless ($variant) {
		        	GENE_INFO($dataid);
			        $sth = $dbh->prepare("select status from GeneStats where sampleid = '$dataid' and status ='done'"); $sth->execute(); $found = $sth->fetch();
							unless ($found) {
								my $genecount = 0; $genecount = $dbh->selectrow_array("select count(*) from GenesFpkm where sampleid = '$dataid'");
				        unless ($genes == $genecount) { # processing for GenesFpkm
									$verbose and printerr "NOTICE:\t Removed incomplete records for $dataid in GenesFpkm table\n";
          				$sth = $dbh->prepare("delete from GenesFpkm where sampleid = '$dataid'"); $sth->execute();
          				printerr "NOTICE:\t Importing $dataid - Genes to GenesFpkm table ...";
          				FPKM('GenesFpkm', $genesfile, $dataid); #GENES
        	  			printerr " Done\n";
				    		} else {
				    				$verbose and printerr "NOTICE:\t $dataid already in GenesFpkm table... Moving on \n";
				  			} #end gene unless
				  			my $isoformscount = 0; $isoformscount = $dbh->selectrow_array("select count(*) from IsoformsFpkm where sampleid = '$dataid'");
				  			unless ($isoforms == $isoformscount) { # processing for IsoformsFpkm
				          	$verbose and printerr "NOTICE:\t Removed incomplete records for $dataid in IsoformsFpkm table\n";
				    				$sth = $dbh->prepare("delete from IsoformsFpkm where sampleid = '$dataid'"); $sth->execute();
				    				printerr "NOTICE:\t Importing $dataid - Isoforms to IsoformsFpkm table ...";
				    				FPKM('IsoformsFpkm', $isoformsfile, $dataid); #ISOFORMS
				  	  			printerr " Done\n";
				    		} else {
				    				$verbose and printerr "NOTICE:\t $dataid already in IsoformsFpkm table... Moving on \n";
				  			}# end isoforms unless
				  			$sth = $dbh->prepare("update GeneStats set status = 'done' where sampleid = '$dataid'");
				  			$sth ->execute() or die "\nERROR:\t Complication in GeneStats table, contact $AUTHOR\n";
							}
							if ($all){
          				my $variantstatus = $dbh->selectrow_array("select status from VarSummary where sampleid = '$dataid' and status = 'done'");
          				unless ($variantstatus){ #checking if completed in VarSummary table
            					$verbose and printerr "NOTICE:\t Removed incomplete records for $dataid in all Variants tables\n";
					        $sth = $dbh->prepare("delete from VarAnno where sampleid = '$dataid'"); $sth->execute();
	            				$sth = $dbh->prepare("delete from VarResult where sampleid = '$dataid'"); $sth->execute();
            					$sth = $dbh->prepare("delete from VarSummary where sampleid = '$dataid'"); $sth->execute();
            					printerr "NOTICE:\t Importing $dataid - Variants to VarResult table ...";
            					DBVARIANT($variantfile, $dataid);
            					printerr " Done\n";
        	    				#variant annotation specifications
	            				if ($vep) {
	      						printerr "TASK:\t Importing Variant annotation from VEP => $file2consider\n"; #status
              						printerr "NOTICE:\t Importing $dataid - Variant Annotation to VarAnno table ...";
             		 				VEPVARIANT($vepfile, $dataid); printerr " Done\n";
							NOSQL($dataid);
            					}
        	    				if ($annovar) {
		      					printerr "TASK:\t Importing Variant annotation from ANNOVAR => $file2consider\n"; #status
              						printerr "NOTICE:\t Importing $dataid - Variant Annotation to VarAnno table ...";
              						ANNOVARIANT($annofile, $dataid); printerr " Done\n";
							NOSQL($dataid);
            					}
          				} else {
        	    				printerr "NOTICE:\t $dataid already in VarResult table... Moving on \n";

						if ($vep || $annovar) {
              						my $variantstatus = $dbh->selectrow_array("select annversion from VarSummary where sampleid = '$dataid'");
							my $nosqlstatus = $dbh->selectrow_array("select nosql from VarSummary where sampleid = '$dataid'");
							unless ($variantstatus && $nosqlstatus){ #if annversion or nosqlstatus is not specified
                						$verbose and printerr "NOTICE:\t Removed incomplete records for $dataid in VarAnno table\n";
                						$sth = $dbh->prepare("delete from VarAnno where sampleid = '$dataid'"); $sth->execute();
        	        					if ($vep) {
									printerr "TASK:\t Importing Variant annotation from VEP => $file2consider\n"; #status
                                                			printerr "NOTICE:\t Importing $dataid - Variant Annotation to VarAnno table ...";
                                                			VEPVARIANT($vepfile, $dataid); printerr " Done\n";
                                                			NOSQL($dataid);
                                        			}
		                	                        if ($annovar) {
	                	                        	        printerr "TASK:\t Importing Variant annotation from ANNOVAR => $file2consider\n"; #status
        	                	                        	printerr "NOTICE:\t Importing $dataid - Variant Annotation to VarAnno table ...";
	        	                        	                ANNOVARIANT($annofile, $dataid); printerr " Done\n";
        	        	                        	        NOSQL($dataid);
                	        	                	}
				        		} else { #end unless annversion is previously specified
                						printerr "NOTICE:\t $dataid already in VarAnno table... Moving on\n";
	              					}
        	    				} #end if annversion is previously specified
																	$additional .=  "Optional: To delete $dataid from Variant tables ; Execute: tad-import.pl -delete $dataid \n";
      			
				      	} #end unless it's already in variants table
        			} #end if "all" option
	      		} #end unless default option is specified 
      			else { #variant option selected
        			my $variantstatus = $dbh->selectrow_array("select status from VarSummary where sampleid = '$dataid' and status = 'done'");
        			unless ($variantstatus){ #checking if completed in VarSummary table
					$verbose and printerr "NOTICE:\t Removed incomplete records for $dataid in all Variants tables\n";
			          	$sth = $dbh->prepare("delete from VarAnno where sampleid = '$dataid'"); $sth->execute();
		          		$sth = $dbh->prepare("delete from VarResult where sampleid = '$dataid'"); $sth->execute();
		        	  	$sth = $dbh->prepare("delete from VarSummary where sampleid = '$dataid'"); $sth->execute();
			          	printerr "NOTICE:\t Importing $dataid - Variants to VarResult table ...";
			          	DBVARIANT($variantfile, $dataid);
			          	printerr " Done\n";
		          		#variant annotation specifications
		        	  	if ($vep) {
			            		printerr "TASK:\t Importing Variant annotation from VEP => $file2consider\n"; #status
			            		printerr "NOTICE:\t Importing $dataid - Variant Annotation to VarAnno table ...";
			            		VEPVARIANT($vepfile, $dataid); printerr " Done\n";
						NOSQL($dataid);
          				}
					if ($annovar) {
            					printerr "TASK:\t Importing Variant annotation from ANNOVAR => $file2consider\n"; #status
            					printerr "NOTICE:\t Importing $dataid - Variant Annotation to VarAnno table ...";
           			 		ANNOVARIANT($annofile, $dataid); printerr " Done\n";
						NOSQL($dataid);
          				}
        			} else { #if completed in VarSummary table
									printerr "NOTICE:\t $dataid already in VarResult table... Moving on \n";
					if ($vep || $annovar) { #checking if vep or annovar was specified
            					my $variantstatus = $dbh->selectrow_array("select annversion from VarSummary where sampleid = '$dataid'");
						my $nosqlstatus = $dbh->selectrow_array("select nosql from VarSummary where sampleid = '$dataid'");
            					unless ($variantstatus && $nosqlstatus){ #if annversion or nosqlstatus is not specified
					              	$verbose and printerr "NOTICE:\t Removed incomplete records for $dataid in all Variant Annotation tables\n";
					              	$sth = $dbh->prepare("delete from VarAnno where sampleid = '$dataid'"); $sth->execute();
					              	if ($vep) {
						                printerr "TASK:\t Importing Variant annotation from VEP => $file2consider\n"; #status
						                printerr "NOTICE:\t Importing $dataid - Variant Annotation to VarAnno table ...";
						                VEPVARIANT($vepfile, $dataid); printerr " Done\n";
								NOSQL($dataid);
              						}
					              	if ($annovar) {
						                printerr "TASK:\t Importing Variant annotation from ANNOVAR => $file2consider\n"; #status
						                printerr "NOTICE:\t Importing $dataid - Variant Annotation to VarAnno table ...";
						                ANNOVARIANT($annofile, $dataid); printerr " Done\n";
								NOSQL($dataid);
              						}
            					} else { #end unless annversion is previously specified
              						printerr "NOTICE:\t $dataid already in VarAnno table... Moving on \n";
            					}
          				} #end if annversion is previously specified
								$additional .=  "Optional: To delete $dataid from Variant tables ; Execute: tad-import.pl -delete $dataid \n";
        			} # end else already in VarSummary table;
      			} #end if "variant" option
    		} #unless & else exists in Mapstats
  	} else {
      		pod2usage("FAILED: \"$dataid\" sample information is not in the database. Make sure the metadata has be previously imported using '-metadata'");
  	} #end if data in sample table
}
if ($delete){
	my (%KEYDELETE);
	my ($i,$alldelete) = (0,0);
	printerr "JOB:\t Deleting Existing Records in Database\n"; #status
	$dbh = mysql($all_details{'MySQL-databasename'}, $all_details{'MySQL-username'}, $all_details{'MySQL-password'}); #connect to mysql
  	$sth = $dbh->prepare("select sampleid from Sample where sampleid = '$delete'"); $sth->execute(); $found = $sth->fetch();
	if ($found) {
		printerr "NOTICE:\t This module deletes records from ALL database systems for TransAtlasDB. Proceed with caution\n";
		$sth = $dbh->prepare("select sampleid from Sample where sampleid = '$delete'"); $sth->execute(); $found =$sth->fetch();
    		if ($found) {
			$i++; $KEYDELETE{$i} = "Sample Information";
		}
		$sth = $dbh->prepare("select sampleid from MapStats where sampleid = '$delete'"); $sth->execute(); $found = $sth->fetch();
    		if ($found) {
			$i++; $KEYDELETE{$i} = "Mapping Information";
		}
		$sth = $dbh->prepare("select sampleid from GeneStats where sampleid = '$delete'"); $sth->execute(); $found = $sth->fetch();
    		if ($found) {
			$i++; $KEYDELETE{$i} = "Gene Information";
		}
		$sth = $dbh->prepare("select sampleid from VarSummary where sampleid = '$delete'"); $sth->execute(); $found = $sth->fetch();
    		if ($found) {
			$i++; $KEYDELETE{$i} = "Variant Information";
		}
		print "--------------------------------------------------------------------------\n";
    		print "The following details match the sampleid '$delete' provided\n";
    		foreach (sort {$a <=> $b} keys %KEYDELETE) { print "  ", uc($_),"\.  $KEYDELETE{$_}\n";}
		$KEYDELETE{0} = "ALL information relating to '$delete'";
		print "  0\.  ALL information relating to '$delete'\n";
		print "--------------------------------------------------------------------------\n";
		print "Choose which details you want removed from the database (multiple option separated by comma) ? ";
		chomp (my $decision = (<>)); print "\n";
		if (length $decision >0) {
			my @allverdict = split(",",$decision);
			foreach my $verdict (sort {$b<=>$a} @allverdict) {
				if (exists $KEYDELETE{$verdict}) {
					printerr "NOTICE:\t Deleting $KEYDELETE{$verdict}\n";
					if ($verdict == 0) {$alldelete = 1;}
					if ($KEYDELETE{$verdict} =~ /^Variant/ || $alldelete == 1) {
						my $ffastbit = fastbit($all_details{'FastBit-path'}, $all_details{'FastBit-foldername'});  #connect to fastbit
						printerr "NOTICE:\t Deleting records for $delete in Variant tables ";
						$sth = $dbh->prepare("delete from VarAnno where sampleid = '$delete'"); $sth->execute(); printerr ".";
						$sth = $dbh->prepare("delete from VarResult where sampleid = '$delete'"); $sth->execute(); printerr ".";
						$sth = $dbh->prepare("delete from VarSummary where sampleid = '$delete'"); $sth->execute(); printerr ".";
						my $execute = "ibis -d $ffastbit -y \"sampleid = '$delete'\" -z";
						`$execute 2>> $efile`; printerr ".";
						printerr " Done\n";
					}
					if ($KEYDELETE{$verdict} =~ /^Gene/ || $alldelete ==1 ) {
						printerr "NOTICE:\t Deleting records for $delete in Gene tables ";
						$sth = $dbh->prepare("delete from GenesFpkm where sampleid = '$delete'"); $sth->execute(); printerr ".";
						$sth = $dbh->prepare("delete from IsoformsFpkm where sampleid = '$delete'"); $sth->execute(); printerr ".";
						$sth = $dbh->prepare("delete from GeneStats where sampleid = '$delete'"); $sth->execute(); printerr ".";
						printerr " Done\n";
					}
					if ($KEYDELETE{$verdict} =~ /^Map/ || $alldelete ==1 ) {
						$sth = $dbh->prepare("select sampleid from GeneStats where sampleid = '$delete'"); $sth->execute(); $found = $sth->fetch();
						unless ($found) {
							$sth = $dbh->prepare("select sampleid from VarSummary where sampleid = '$delete'"); $sth->execute(); $found = $sth->fetch();
							unless ($found) {
								printerr "NOTICE:\t Deleting records for $delete in Mapping tables .";
								$sth = $dbh->prepare("delete from Metadata where sampleid = '$delete'"); $sth->execute(); printerr ".";
								$sth = $dbh->prepare("delete from MapStats where sampleid = '$delete'"); $sth->execute();  printerr ".";
								printerr " Done\n";
							} else { printerr "ERROR:\t Variant Information relating to '$delete' is in the database. Delete Variant Information first\n";}
						} else { printerr "ERROR:\t Gene Information Relating to '$delete' still present in the database. Delete Gene Information first\n";}
					}
					if ($KEYDELETE{$verdict} =~ /^Sample/ || $alldelete ==1 ) {
						$sth = $dbh->prepare("select sampleid from MapStats where sampleid = '$delete'"); $sth->execute(); $found = $sth->fetch();
						unless ($found) {
							$sth = $dbh->prepare("select sampleid from GeneStats where sampleid = '$delete'"); $sth->execute(); $found = $sth->fetch();
							unless ($found) {
								$sth = $dbh->prepare("select sampleid from VarSummary where sampleid = '$delete'"); $sth->execute(); $found = $sth->fetch();
								unless ($found) {
									printerr "NOTICE:\t Deleting records for $delete in Sample tables ";
									$sth = $dbh->prepare("delete from SampleStats where sampleid = '$delete'"); $sth->execute(); printerr ".";
									$sth = $dbh->prepare("delete from SampleOrganization where sampleid = '$delete'"); $sth->execute(); printerr ".";
									$sth = $dbh->prepare("delete from SamplePerson where sampleid = '$delete'"); $sth->execute(); printerr ".";
									$sth = $dbh->prepare("delete from Sample where sampleid = '$delete'"); $sth->execute();  printerr ".";
									printerr " Done\n";
								} else { printerr "ERROR:\t Variant Information for '$delete' is in the database. Delete Variant Information first\n"; }
							} else { printerr "ERROR:\t Gene Information for '$delete' still present in the database. Delete Gene Information first\n"; }
						} else { printerr "ERROR:\t Mapping Information for '$delete' is in the database. Delete Mapping Information first\n"; }
					}
				} else { printerr "ERROR:\t $verdict is an INVALID OPTION\n"; }
			}
		} else {printerr "NOTICE:\t No Option selected\n";}
	} else {
		printerr "NOTICE:\t Information relating to '$delete' is not in the database. Good-bye\n";
	}
}
#output: the end
printerr "-----------------------------------------------------------------\n";
if ($metadata){
  	printerr ("SUCCESS: Import of Sample Information in \"$file2consider\"\n");
} #end if complete RNASeq metadata
if ($datadb){
  	printerr ("SUCCESS: Import of RNA Seq analysis information in \"$file2consider\"\n");
} #end if completed RNASeq data2db
printerr $additional;
$transaction = "data to database import" if $datadb;
$transaction = "METADATA IMPORT(s)" if $metadata;
$transaction = "DELETE '$delete' activity" if $delete;
printerr ("NOTICE:\t Summary of $transaction in log file $efile\n");
printerr "-----------------------------------------------------------------\n";
print LOG "TransAtlasDB Completed:\t", scalar(localtime),"\n";
close (LOG);
#--------------------------------------------------------------------------------

sub processArguments {
	my @commandline = @ARGV;
  	GetOptions('verbose|v'=>\$verbose, 'help|h'=>\$help, 'man|m'=>\$man, 'metadata'=>\$metadata,
		'data2db'=>\$datadb, 'gene'=>\$gene, 'variant'=>\$variant, 'all'=>\$all, 'vep'=>\$vep,
		'annovar'=>\$annovar, 't|tab'=>\$tab, 'x|excel'=>\$excel, 'delete=s'=>\$delete ) or pod2usage ();

	$help and pod2usage (-verbose=>1, -exitval=>1, -output=>\*STDOUT);
  	$man and pod2usage (-verbose=>2, -exitval=>1, -output=>\*STDOUT);  
  
	pod2usage(-msg=>"ERROR:\t Invalid syntax specified, choose -metadata or -data2db or -delete.") unless ( $metadata || $datadb|| $delete);
	pod2usage(-msg=>"ERROR:\t Invalid syntax specified for @commandline.") if (($metadata && $datadb)||($vep && $annovar) || ($gene && $vep) || ($gene && $annovar) || ($gene && $variant));
	if ($vep || $annovar) {
		pod2usage(-msg=>"ERROR:\t Invalid syntax specified for @commandline, specify -variant.") unless (($variant && $annovar)||($variant && $vep) || ($all && $annovar) || ($all && $vep));
	}
  	@ARGV<=1 or pod2usage("Syntax error");
  	$file2consider = $ARGV[0];
  	
	$verbose ||=0;
	my $get = dirname(abs_path $0); #get source path
	$connect = $get.'/.connect.txt';
	#setup log file
	$efile = @{ open_unique("db.tad_status.log") }[1];
	$nosql = @{ open_unique(".nosqlimport.txt") }[1]; `rm -rf $nosql`;
	open(LOG, ">>", $efile) or die "\nERROR:\t cannot write LOG information to log file $efile $!\n";
	print LOG "TransAtlasDB Version:\t",$VERSION,"\n";
	print LOG "TransAtlasDB Information:\tFor questions, comments, documentation, bug reports and program update, please visit $default \n";
	print LOG "TransAtlasDB Command:\t $0 @commandline\n";
	print LOG "TransAtlasDB Started:\t", scalar(localtime),"\n";
}

sub LOGFILE { #subroutine for getting metadata
	if ($logfile){
		@allgeninfo = split('\s',`head -n 1 $logfile`);
		#also getting metadata info
		if ($allgeninfo[1] =~ /.*library-type$/ && $allgeninfo[3] =~ /.*no-coverage-search$/){$str = 2; $ann = 5; $ref = 10; $seq = 11; $allstart = 4; $allend = 7;}
		elsif ($allgeninfo[1] =~ /.*library-type$/ && $allgeninfo[3] =~ /.*G$/ ){$str = 2; $ann = 4; $ref = 9; $seq = 10; $allstart = 3; $allend = 6;}
		elsif($allgeninfo[3] =~ /\-o$/){$str=99; $ann=99; $ref = 5; $seq = 6; $allstart = 3; $allend = 6;}
		$refgenome = (split('\/', $allgeninfo[$ref]))[-1]; #reference genome name
	}
	else {
		($str, $ann, $ref, $seq,$allstart, $allend) = (99,99,99,99,99,99); #defining calling variables
	}
	unless ($ann == 99){
		$annotation = $allgeninfo[$ann];
		$annotationfile = uc ( (split('\.',((split("\/", $allgeninfo[$ann]))[-1])))[-1] ); #(annotation file)
	}
	else { $annotation = undef; $annotationfile = undef; }
	if ($str == 99){ $stranded = undef; } else { $stranded = $allgeninfo[$str]; } # (stranded or not)	
	if ($seq == 99) { $sequences = undef;} else {
		my $otherseq = $seq++;
		unless(length($allgeninfo[$otherseq])<1){ #sequences 
			$sequences = ( ( split('\/', $allgeninfo[$seq]) ) [-1]).",". ( ( split('\/', $allgeninfo[$otherseq]) ) [-1]);
		} else {
			$sequences = ( ( split('\/', $allgeninfo[$seq]) ) [-1]);
		}
	} #end if seq
}

sub GENE_INFO { #subroutine for getting gene information
	$deletions = `cat $deletionsfile | wc -l`; $deletions--;
	$insertions = `cat $insertionsfile | wc -l`; $insertions--;
	$junctions = `cat $junctionsfile | wc -l`; $junctions--;
	$genes = `cat $genesfile | wc -l`; $genes--;
	$isoforms = `cat $isoformsfile | wc -l`; $isoforms--;

	#INSERT INTO DATABASE: #GeneStats table
	$sth = $dbh->prepare("select sampleid from GeneStats where sampleid = '$_[0]'"); $sth->execute(); $found = $sth->fetch();
	unless ($found) { 
		printerr "NOTICE:\t Importing $_[0] to GeneStats table\n";
		$sth = $dbh->prepare("insert into GeneStats (sampleid,deletions, insertions, junctions, isoforms, genes,date) values (?,?,?,?,?,?,?)");
		$sth ->execute($_[0], $deletions, $insertions, $junctions, $isoforms, $genes, $date) or die "\nERROR:\t Complication in GeneStats table, contact $AUTHOR\n";; 
	} else {
		printerr "NOTICE:\t $_[0] already in GeneStats table... Moving on \n";
		$sth = $dbh->prepare("select status from GeneStats where sampleid = '$_[0]' and status ='done'"); $sth->execute(); $found = $sth->fetch();
		if ($found) { 
			$additional .=  "Optional: To delete $_[0] from GeneStats table ; Execute: tad-import.pl -delete $_[0] \n";
		}
	}
}

sub FPKM { #subroutine for  importing the FPKM values
	open(FPKM, "<", $_[1]) or die "\nERROR:\t Can not open file $_[1]\n";
	my $syntax = "insert into $_[0] (sampleid, trackingid, classcode, nearestrefid, geneid, geneshortname, tssid, chromnumber, chromstart, chromstop, length, coverage, fpkm, fpkmconflow, fpkmconfhigh, fpkmstatus ) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
	my $sth = $dbh->prepare($syntax);
	while (<FPKM>){
		chomp;
		my ($track, $class, $ref_id, $gene, $gene_name, $tss, $locus, $length, $coverage, $fpkm, $fpkm_low, $fpkm_high, $fpkm_stat ) = split /\t/;
		unless ($track eq "tracking_id"){ #check & specifying undefined variables to null
			if($class =~ /-/){$class = undef;} if ($ref_id =~ /-/){$ref_id = undef;}
			if ($length =~ /-/){$length = undef;} if($coverage =~ /-/){$coverage = undef;}
			my ($chrom_no, $chrom_start, $chrom_stop) = $locus =~ /^(.+)\:(.+)\-(.+)$/;
			$sth ->execute($_[2], $track, $class, $ref_id, $gene, $gene_name, $tss, $chrom_no, $chrom_start, $chrom_stop, $length, $coverage, $fpkm, $fpkm_low, $fpkm_high, $fpkm_stat ) or die "\nERROR:\t Complication in $_[0] table, contact $AUTHOR\n";
		}
	} close FPKM;
	$sth->finish();
}

sub DBVARIANT {
	open(VARVCF,$_[0]) or die ("\nERROR:\t Can not open variant file $_[0]\n");
	$varianttool = "samtools";
	while (<VARVCF>) {
		chomp;
		if (/^\#/) { if (/^\#\#GATK/) { $varianttool = "GATK"; } }
		else {
			my @chrdetails = split "\t";
			my @morechrsplit = split(';', $chrdetails[7]);
			if (((split(':', $chrdetails[9]))[0]) eq '0/1'){$verd = "heterozygous";}
			elsif (((split(':', $chrdetails[9]))[0]) eq '1/1'){$verd = "homozygous";}
			elsif (((split(':', $chrdetails[9]))[0]) eq '1/2'){$verd = "heterozygous alternate";}
			$VCFhash{$chrdetails[0]}{$chrdetails[1]} = "$chrdetails[3]|$chrdetails[4]|$chrdetails[5]|$verd";
		}
	} close VARVCF;
	$sth = $dbh->prepare("insert into VarSummary ( sampleid, varianttool, date) values (?,?,?)");
	$sth ->execute($_[1], $varianttool, $date) or die "\nERROR:\t Complication in VarSummary table, contact $AUTHOR\n";;

	#VARIANT_RESULTS
	foreach my $abc (sort keys %VCFhash) {
		foreach my $def (sort {$a <=> $b} keys %{ $VCFhash{$abc} }) {
			my @vcf = split('\|', $VCFhash{$abc}{$def});
			if ($vcf[3] =~ /,/){
				my $first = split(",",$vcf[1]);
				if (length $vcf[0] == length $first){ $itvariants++; $itsnp++; $variantclass = "SNV"; }
				elsif (length $vcf[0] < length $first) { $itvariants++; $itindel++; $variantclass = "insertion"; }
				else { $itvariants++; $itindel++; $variantclass = "deletion"; }
			}
			elsif (length $vcf[0] == length $vcf[1]){ $itvariants++; $itsnp++; $variantclass = "SNV"; }
			elsif (length $vcf[0] < length $vcf[1]) { $itvariants++; $itindel++; $variantclass = "insertion"; }
			else { $itvariants++; $itindel++; $variantclass = "deletion"; }

			#to variant_result
			$sth = $dbh->prepare("insert into VarResult ( sampleid, chrom, position, refallele, altallele, quality, variantclass, zygosity ) values (?,?,?,?,?,?,?,?)");
			$sth ->execute($_[1], $abc, $def, $vcf[0], $vcf[1], $vcf[2], $variantclass, $vcf[3]) or die "\nERROR:\t Complication in VarResult table, contact $AUTHOR\n";
		}
	}
	#update variantsummary with counts
	$sth = $dbh->prepare("update VarSummary set totalvariants = $itvariants, totalsnps = $itsnp, totalindels = $itindel where sampleid= '$_[1]'");
	$sth ->execute();
	$sth = $dbh->prepare("update VarSummary set status = 'done' where sampleid= '$_[1]'");
	$sth ->execute();
	$sth->finish();
}

sub VEPVARIANT {
	my ($chrom, $position);
	open(VEP,$_[0]) or die ("\nERROR:\t Can not open vep file $_[0]\n");
	while (<VEP>) {
		chomp;
		unless (/^\#/) {
			unless (/within_non_coding_gene/i || /coding_unknown/i) {
				my @veparray = split "\t"; #14 columns
				my @extraarray = split(";", $veparray[13]);
				foreach (@extraarray) { my @earray = split "\="; $extra{$earray[0]}=$earray[1]; }
				my @indentation = split("_", $veparray[0]);
				if ($#indentation > 2) { $chrom = $indentation[0]."_".$indentation[1]; $position = $indentation[2]; }
				else { $chrom = $indentation[0]; $position = $indentation[1]; }
				$chrom = "chr".$chrom;
				unless ($extra{'VARIANT_CLASS'} =~ "SNV" or $extra{'VARIANT_CLASS'} =~ "substitution"){ $position--; }
				my $geneid = $veparray[3];
				my $transcriptid = $veparray[4];
				my $featuretype = $veparray[5];
				my $consequence = $veparray[6]; 
				if ($consequence =~ /NON_(.*)$/){ $consequence = "NON".$1; } elsif ($consequence =~ /STOP_(.*)$/) {$consequence = "STOP".$1; }
				my $pposition = $veparray[9];
				my $aminoacid = $veparray[10];
				my $codons = $veparray[11];
				my $dbsnp = $veparray[12];
				my $locate = "$_[1],$chrom,$position,$consequence,$geneid,$pposition";
				if ( exists $VEPhash{$locate} ) {
					unless ( $VEPhash{$locate} eq $locate ){ die "\nERROR:\t Duplicate annotation in VEP file, contact $AUTHOR\n"; }
				} else {
					$VEPhash{$locate} = $locate;
					$sth = $dbh->prepare("insert into VarAnno ( sampleid, chrom, position, consequence, source, geneid, genename, transcript, feature, genetype,proteinposition, aachange, codonchange ) values (?,?,?,?,?,?,?,?,?,?,?,?,?)");
					if (exists $extra{'SYMBOL'}) { $extra{'SYMBOL'} = uc($extra{'SYMBOL'}); }
					$sth ->execute($_[1], $chrom, $position, $consequence, $extra{'SOURCE'}, $geneid, $extra{'SYMBOL'}, $transcriptid, $featuretype, $extra{'BIOTYPE'} , $pposition, $aminoacid, $codons) or die "\nERROR:\t Complication in VarAnno table, contact $AUTHOR\n";
					
					#NOSQL portion
					@nosqlrow = $dbh->selectrow_array("select * from vw_nosql where sampleid = '$_[1]' and chrom = '$chrom' and position = $position and consequence = '$consequence' and geneid = '$geneid' and proteinposition = '$pposition'");
					$showcase = undef; 
					foreach my $variables (0..$#nosqlrow){
						if ($variables == 2) { $nosqlrow[$variables] = $dbsnp; }
						if (!($nosqlrow[$variables]) ||(length($nosqlrow[$variables]) < 1) || ($nosqlrow[$variables] =~ /^\-$/) ){
							$nosqlrow[$variables] = "NULL";
						}
						if ($variables < 17) {
							$showcase .= "'$nosqlrow[$variables]',";
						}
						else {
							$showcase .= "$nosqlrow[$variables],";
						}
					}
					chop $showcase; $showcase .= "\n";
					open (NOSQL, ">>$nosql"); print NOSQL $showcase; close NOSQL; #end of nosql portion
					undef %extra; #making sure extra is blank
					$DBSNP{$chrom}{$position} = $dbsnp; #updating dbsnp	
				}
			}
		}
	}
	close VEP;
	foreach my $chrom (sort keys %DBSNP) {
		foreach my $position (sort keys %{ $DBSNP{$chrom} }) {
			$sth = $dbh->prepare("update VarResult set dbsnpvariant = '$DBSNP{$chrom}{$position}' where sampleid = '$_[1]' and chrom = '$chrom' and position = $position"); $sth ->execute();
		}
	}
	$sth = $dbh->prepare("update VarSummary set annversion = 'VEP' where sampleid = '$_[1]'"); $sth ->execute();
}

sub ANNOVARIANT {
	my (%REFGENE, %ENSGENE, %CONTENT);
	open(ANNOVAR,$_[0]) or die ("\nERROR:\t Can not open annovar file $_[0]\n");
	my @annocontent = <ANNOVAR>; close ANNOVAR; 
	my @header = split("\t", lc($annocontent[0]));

	#getting headers
	foreach my $no (5..$#header-1){ #checking if ens and ref is specified
		my @tobeheader = split('\.', $header[$no]);
		if ($tobeheader[1] =~ /refgene/i){
			$REFGENE{$tobeheader[0]} = $header[$no];
		} elsif ($tobeheader[1] =~ /ensgene/i){ 
			$ENSGENE{$tobeheader[0]} = $header[$no];
		} else {
			die "ERROR:\t Do not understand notation '$tobeheader[1]' provided. Contact $AUTHOR \n";
		}
	} #end foreach dictionary
	#convert content to a hash array.
	my $counter = $#header+1;
	@annocontent = @annocontent[1..$#annocontent];
	foreach my $rowno (0..$#annocontent) {
		unless ($annocontent[$rowno] =~ /intergenic.*NONE,NONE/i) {
			my @arrayrow = split("\t", $annocontent[$rowno], $counter);
			foreach my $colno (0..$#header) {
				$CONTENT{$rowno}{$header[$colno]} = $arrayrow[$colno];
			}
			$CONTENT{$rowno}{'position'} = (split("\t",$arrayrow[$#arrayrow]))[4];
		} # end unless var annotation is useless
	} #end getting column position o entire file
	#working with ENS
	if (exists $ENSGENE{'func'}) {
		foreach my $newno (sort {$a<=>$b} keys %CONTENT){
			my $pposition = "-"; my $consequence = ""; my $transcript = ""; my $aminoacid = "-"; my $codons = "-";
			if ($CONTENT{$newno}{$ENSGENE{'func'}} =~ /^exonic/i) {
				$consequence = $CONTENT{$newno}{$ENSGENE{'exonicfunc'}};
				unless ($consequence =~ /unknown/i){         
					my @acontent = split(",", $CONTENT{$newno}{$ENSGENE{'aachange'}});
					my @ocontent = split (":", $acontent[$#acontent]);
					$transcript = $ocontent[1] =~ s/\.\d//g;
					foreach (@ocontent){
						if (/^c\.[a-zA-Z]/) {
							my ($a, $b, $c) = $_ =~ /^c\.(\S)(\d+)(\S)$/; 
							$codons = $a."/".$c;
						} elsif (/^c\.[0-9]/) {
							$codons = $_;
						} elsif (/^p\.\S\d+\S$/){ 
							my ($a, $b, $c) = $_ =~ /^p\.(\S)(\d+)(\S)$/;
							$pposition = $b;
							if ($a eq $c) {$aminoacid = $a;} else {$aminoacid = $a."/".$b;}
						} elsif (/^p\.\S\d+\S+$/) {
							my $a = $_ =~ /^p\.\S(\d+)\S+$/;
							$pposition = $a;
							$aminoacid = $_;
						}
					} #end foreach @ocontent
				} else {next;} 
			} else {
				$consequence = $CONTENT{$newno}{$ENSGENE{'func'}};
			}
			unless ($consequence =~ /ncRNA/i) {
				$consequence = uc($consequence);
				if ($consequence eq "UTR5"){ $consequence = "5PRIME_UTR";}
				if ($consequence eq "UTR3"){ $consequence = "3PRIME_UTR";} 
			}
			$CONTENT{$newno}{$ENSGENE{'gene'}} =~ s/\.\d//g; 
			my $locate = "$_[1],$CONTENT{$newno}{'chr'}, $CONTENT{$newno}{'position'},$consequence,$CONTENT{$newno}{$ENSGENE{'gene'}},$pposition";
			if ( exists $ANNOhash{$locate} ) {
				unless ( $ANNOhash{$locate} eq $locate ){ die "\nERROR:\t Duplicate annotation in ANNOVAR file, contact $AUTHOR\n"; }
			} else {
				$ANNOhash{$locate} = $locate;
				$sth = $dbh->prepare("insert into VarAnno ( sampleid, chrom, position, consequence, source, geneid, transcript,proteinposition, aachange, codonchange ) values (?,?,?,?,?,?,?,?,?,?)");
				$sth ->execute($_[1], $CONTENT{$newno}{'chr'}, $CONTENT{$newno}{'position'}, $consequence, 'Ensembl', $CONTENT{$newno}{$ENSGENE{'gene'}}, $transcript, $pposition, $aminoacid, $codons) or die "\nERROR:\t Complication in VarAnno table, contact $AUTHOR\n";

				#NOSQL portion
				@nosqlrow = $dbh->selectrow_array("select * from vw_nosql where sampleid = '$_[1]' and chrom = '$CONTENT{$newno}{'chr'}' and position = $CONTENT{$newno}{'position'} and consequence = '$consequence' and geneid = '$CONTENT{$newno}{$ENSGENE{'gene'}}' and proteinposition = '$pposition'");
				$showcase = undef; 
				foreach my $variables (0..$#nosqlrow) {
					if (!($nosqlrow[$variables]) ||(length($nosqlrow[$variables]) < 1) || ($nosqlrow[$variables] =~ /^\-$/) ){
						$nosqlrow[$variables] = "NULL";
					}
					if ($variables < 17) {
						$showcase .= "'$nosqlrow[$variables]',";
					}
					else {
						$showcase .= "$nosqlrow[$variables],";
					}
				}
				chop $showcase; $showcase .= "\n";
				open (NOSQL, ">>$nosql"); print NOSQL $showcase; close NOSQL; #end of nosql portion
			} #end if annohash locate
		} # end foreach looking at content
	} #end if ENSGENE

	#working with REF
	if (exists $REFGENE{'func'}) {
		foreach my $newno (sort {$a<=>$b} keys %CONTENT){
			my $pposition = "-"; my $consequence = ""; my $transcript = ""; my $aminoacid = ""; my $codons = "";
			if ($CONTENT{$newno}{$REFGENE{'func'}} =~ /^exonic/i) {
				$consequence = $CONTENT{$newno}{$REFGENE{'exonicfunc'}};
				unless ($consequence =~ /unknown/i){         
					my @acontent = split(",", $CONTENT{$newno}{$REFGENE{'aachange'}});
					my @ocontent = split (":", $acontent[$#acontent]);
					$transcript = $ocontent[1] =~ s/\.\d//g;
					foreach (@ocontent){
						if (/^c\.[a-zA-Z]/) {
							my ($a, $b, $c) = $_ =~ /^c\.(\S)(\d+)(\S)$/; 
							$codons = $a."/".$c;
						} elsif (/^c\.[0-9]/) {
							$codons = $_;
						} elsif (/^p\.\S\d+\S$/){ 
							my ($a, $b, $c) = $_ =~ /^p\.(\S)(\d+)(\S)$/;
							$pposition = $b;
							if ($a eq $c) {$aminoacid = $a;} else {$aminoacid = $a."/".$b;}
						} elsif (/^p\.\S\d+\S+$/) {
							my $a = $_ =~ /^p\.\S(\d+)\S+$/;
							$pposition = $a;
							$aminoacid = $_;
						}
					}
				} else {next;}
			} else {
				$consequence = $CONTENT{$newno}{$REFGENE{'func'}};
			}
			unless ($consequence =~ /ncRNA/i) {
				$consequence = uc($consequence);
				if ($consequence eq "UTR5"){ $consequence = "5PRIME_UTR";}
				if ($consequence eq "UTR3"){ $consequence = "3PRIME_UTR";} 
			}
			$CONTENT{$newno}{$REFGENE{'gene'}} =~ s/\.\d//g;
			my $locate = "$_[1],$CONTENT{$newno}{'chr'}, $CONTENT{$newno}{'position'},$consequence,$CONTENT{$newno}{$REFGENE{'gene'}},$pposition";
			if ( exists $ANNOhash{$locate} ) {
				unless ( $ANNOhash{$locate} eq $locate ){ die "\nERROR:\t Duplicate annotation in ANNOVAR file, contact $AUTHOR\n"; }
			} else {
				$ANNOhash{$locate} = $locate;
				$sth = $dbh->prepare("insert into VarAnno ( sampleid, chrom, position, consequence, source, genename, geneid, transcript,proteinposition, aachange, codonchange ) values (?,?,?,?,?,?,?,?,?,?,?)");
				if (exists $CONTENT{$newno}{$REFGENE{'gene'}}) { $CONTENT{$newno}{$REFGENE{'gene'}} = uc($CONTENT{$newno}{$REFGENE{'gene'}}); }
				$sth ->execute($_[1], $CONTENT{$newno}{'chr'}, $CONTENT{$newno}{'position'}, $consequence, 'RefSeq', $CONTENT{$newno}{$REFGENE{'gene'}}, $CONTENT{$newno}{$REFGENE{'gene'}}, $transcript, $pposition, $aminoacid, $codons) or die "\nERROR:\t Complication in VarAnno table, contact $AUTHOR\n";

				#NOSQL portion
				@nosqlrow = $dbh->selectrow_array("select * from vw_nosql where sampleid = '$_[1]' and chrom = '$CONTENT{$newno}{'chr'}' and position = $CONTENT{$newno}{'position'} and consequence = '$consequence' and geneid = '$CONTENT{$newno}{$REFGENE{'gene'}}' and proteinposition = '$pposition'");
				$showcase = undef; 
				foreach my $variables (0..$#nosqlrow){
					if (!($nosqlrow[$variables]) ||(length($nosqlrow[$variables]) < 1) || ($nosqlrow[$variables] =~ /^\-$/) ){
						$nosqlrow[$variables] = "NULL";
					}
					if ($variables < 17) {
						$showcase .= "'$nosqlrow[$variables]',";
					}
					else {
						$showcase .= "$nosqlrow[$variables],";
					}
				}
				chop $showcase; $showcase .= "\n";
				open (NOSQL, ">>$nosql"); print NOSQL $showcase; close NOSQL; #end of nosql portion
			} #end if annohash locate
		} # end foreach looking at content
	} #end if REFGENE
	$sth = $dbh->prepare("update VarSummary set annversion = 'ANNOVAR' where sampleid = '$_[1]'"); $sth ->execute(); #update database annversion :  ANNOVAR
}

sub NOSQL {
	printerr "TASK:\t Importing Variant annotation for $_[0] to NoSQL platform\n"; #status
	my $ffastbit = fastbit($all_details{'FastBit-path'}, $all_details{'FastBit-foldername'});  #connect to fastbit
	printerr "NOTICE:\t Importing $_[0] - Variant Annotation to NoSQL '$ffastbit' ...";
	my $execute = "ardea -d $ffastbit -m 'variantclass:key,zygosity:key,dbsnpvariant:text,consequence:text,geneid:text,genename:text,transcript:text,feature:text,genetype:text,refallele:char,altallele:char,tissue:text,chrom:key,aachange:text,codonchange:text,organism:key,sampleid:text,quality:double,position:int,proteinposition:int' -t $nosql";
	`$execute 2>> $efile` or die "\nERROR\t: Complication importing to FastBit, contact $AUTHOR\n";
	`rm -rf $nosql`;
	$sth = $dbh->prepare("update VarSummary set nosql = 'done' where sampleid = '$_[0]'"); $sth ->execute(); #update database nosql : DONE
	printerr " Done\n";
}
#--------------------------------------------------------------------------------


=head1 SYNOPSIS

 tad-import.pl [arguments] <metadata-file|sample-location>

 Optional arguments:
        -h, --help                      print help message
        -m, --man                       print complete documentation
        -v, --verbose                   use verbose output

	Arguments to import metadata or sample analysis
            --metadata			import metadata file provided
            --data2db                	import data files from gene expression profiling and/or variant analysis (default: --gene)
            --delete			delete existing information based on sampleid

        Arguments to control metadata import
    	    -x, --excel         	metadata will import the faang excel file provided (default)
	    -t, --tab         		metadata will import the tab-delimited file provided
 
        Arguments to control data2db import
            --gene	     		data2db will import only the alignment file [TopHat2] and expression profiling files [Cufflinks] (default)
            --variant           	data2db will import only the alignment file [TopHat2] and variant analysis files [.vcf]
	    --all          		data2db will import all data files specified

        Arguments to fine-tune variant import procedure
     	    --vep			import ensembl vep variant annotation file [tab-delimited format] [suffix: .vep.txt] (in variant/all operation)
	    --annovar			import annovar variant annotation file [suffix: .multianno.txt] (in variant/all operation)



 Function: import data files into the database

 Example: #import metadata files
          tad-import.pl -metadata -v example/metadata/FAANG/FAANG_GGA_UD.xlsx
          tad-import.pl -metadata -v -t example/metadata/TEMPLATE/metadata_GGA_UD.txt
 	   
	  #import transcriptome analysis data files
	  tad-import.pl -data2db example/sample_sxt/GGA_UD_1004/
	  tad-import.pl -data2db -all -v example/sample_sxt/GGA_UD_1014/
	  tad-import.pl -data2db -variant -annovar example/sample_sxt/GGA_UD_1004/
		
		#delete previously imported data data
	  tad-import.pl -delete GGA_UD_1004


 Version: $Date: 2016-10-28 15:50:08 (Fri, 28 Oct 2016) $

=head1 OPTIONS

=over 8

=item B<--help>

print a brief usage message and detailed explantion of options.

=item B<--man>

print the complete manual of the program.

=item B<--verbose>

use verbose output.

=item B<--metadata>

import metadata file provided.
Metadata files accepted is either a tab-delmited (suffix: '.txt') file 
or FAANG biosamples excel (suffix: '.xls') file

=item B<--tab>

specify the file provided is in tab-delimited format (suffix: '.txt'). (default)

=item B<--excel>

specify the file provided is an excel spreadsheet (suffix: '.xls'/'.xlsx')

=item B<--data2db>

import data files from gene expression profiling analysis 
derived from using TopHat2 and Cufflinks. Optionally 
import variant file (see: variant file format) and 
variant annotation file from annovar or vep.

=item B<--gene>

specify only expression files will be imported. (default)

=item B<--variant>

specify only variant files will be imported.

=item B<--all>

specify both expression and variant files will be imported.

=item B<--vep>

specify annotation file provided was generated using Ensembl Variant Effect Predictor (VEP).

=item B<--annovar>

specify annotation file provided was predicted using ANNOVAR.

=item B<--delete>

delete previously imported information based on sampleid.

=back

=head1 DESCRIPTION

TransAtlasDB is a database management system for organization of gene expression
profiling from numerous amounts of RNAseq data.

TransAtlasDB toolkit comprises of a suite of Perl script for easy archival and 
retrival of transcriptome profiling and genetic variants.

TransAtlasDB requires all analysis be stored in a single folder location for 
successful processing.

Detailed documentation for TransAtlasDB should be viewed on github.

=over 8 

=item * B<directory/folder structure>
A sample directory structure contains file output from TopHat2 software, 
Cufflinks software, variant file from any bioinformatics variant analysis package
such as GATK, SAMtools, and (optional) variant annotation results from ANNOVAR 
or Ensembl VEP in tab-delimited format having suffix '.multianno.txt' and '.vep.txt' 
respectively. An example is shown below:

	/sample_name/
	/sample_name/tophat_folder/
	/sample_name/tophat_folder/accepted_hits.bam
	/sample_name/tophat_folder/align_summary.txt
	/sample_name/tophat_folder/deletions.bed
	/sample_name/tophat_folder/insertions.bed
	/sample_name/tophat_folder/junctions.bed
	/sample_name/tophat_folder/prep_reads.info
	/sample_name/tophat_folder/unmapped.bam
	/sample_name/cufflinks_folder/
	/sample_name/cufflinks_folder/genes.fpkm_tracking
	/sample_name/cufflinks_folder/isoforms.fpkm_tracking
	/sample_name/cufflinks_folder/skipped.gtf
	/sample_name/cufflinks_folder/transcripts.gtf
	/sample_name/variant_folder/
	/sample_name/variant_folder/<filename>.vcf
	/sample_name/variant_folder/<filename>.multianno.txt
	/sample_name/variant_folder/<filename>.vep.txt

=item * B<variant file format>

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

=item * B<invalid input>

If any of the files input contain invalid arguments or format, TransAtlas 
will terminate the program and the invalid input with the outputted. 
Users should manually examine this file and identify sources of error.

=back


--------------------------------------------------------------------------------

TransAtlasDB is free for academic, personal and non-profit use.

For questions or comments, please contact $ Author: Modupe Adetunji <amodupe@udel.edu> $.

=cut


