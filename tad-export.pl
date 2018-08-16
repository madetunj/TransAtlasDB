#!/usr/bin/env perl
use warnings;
use strict;
use Pod::Usage;
use Getopt::Long;
use File::Spec;
use File::Basename;
use Cwd qw(abs_path);
use lib dirname(abs_path $0) . '/lib';
use threads;
use Thread::Queue;
use CC::Create;
use CC::Parse;

our $VERSION = '$ Version: 3 $';
our $DATE = '$ Date: 2017-05-05 05:14:00 (Fri, 05 May 2017) $';
our $AUTHOR= '$ Author:Modupe Adetunji <amodupe@udel.edu> $';

#--------------------------------------------------------------------------------
print "\n";
our ($verbose, $efile, $help, $man, $nosql, $tmpout, $log);
our ($dbh, $sth, $found, $count, @header, @row, $connect, $fastbit);
our ($query, $querynosql, $output,$avgexp, $gene, $tissue, $organism, $genexp, $chrvar, $sample, $chromosome, $varanno, $region, $vcf, $exfpkm, $extpm);
my ($dbdata, $table, $outfile, $syntax, $status, $vcfsyntax);
my $tmpname = rand(20);
our (%ARRAYQUERY, %SAMPLE);

#genexp module
my (@genearray, @VAR, $newfile, @threads, @headers); #splicing the genes into threads
my ($realstart, $realstop, $queue);
my (%FPKM, %CHROM, %POSITION, %REALPOST);
#chrvar module
my (%VARIANTS, %SNPS, %INDELS);
#vcf optino
my (%GT, %TISSUE, %REF, %ALT, %QUAL, %CSQ, %DBSNP, $chrheader, $consequenceheader);
my (%ODACSQ,%number, %NEWQUAL, %NEWCSQ, %NEWREF, %NEWDBSNP, %NEWALT,%NEWGT);
my (%subref, %subalt, %subgt,%MTD);

#--------------------------------------------------------------------------------

sub printerr; #declare error routine
our ($ibis, $ardea) = fastbit_name(); #ibis and ardea location
our $default = DEFAULTS(); #default error contact
processArguments(); #Process input

my %all_details = %{connection($connect, $default)}; #get connection details
if (length($ibis) < 1){ ($ibis, $ardea) = ($all_details{'FastBit-ibis'}, $all_details{'FastBit-ardea'}); } #alternative for ibis and ardea location 
if ($query) { #if user query mode selected
    $query =~ s/^\s+|\s+$//g; $querynosql =~ s/^\s+|\s+$//g;
    unless ($log) { 
        $verbose and printerr "NOTICE:\t User query module selected\n";
        if ($querynosql) { $verbose and printerr "NOTICE:\t NoSQL Query module selected\n"; }
    }

    undef %ARRAYQUERY;
    $count = 0;
    if ($querynosql){
        my $newquery;
        if ($query =~ /\swhere\s/) { $query =~ /select (.+) where/; $newquery = $1; }
        else { $query =~ /select (.+)/; $newquery = $1;} 
        $newquery =~ s/\s//g; $newquery = uc($newquery);
        @header = split("\,",$newquery);
        $fastbit = fastbit($all_details{'FastBit-path'}, $all_details{'FastBit-foldername'});  #connect to fastbit
        $querynosql = $fastbit."/".$querynosql;
        `$ibis -d $querynosql -q '$query' -o $nosql 2>>$efile`;
        
        $table = Text::TabularDisplay->new( @header );
        my $found = `head -n 1 $nosql`;
        if (length($found) > 1) {
            open(IN,"<",$nosql);
            while (<IN>){
                chomp;
                my @row = undef; 
                my @all = split (/\, /, $_);
                foreach (@all) { 
                    $_ =~ s/^'|'$|^"|"$//g; #removing the quotation marks from the words 
                    push @row, $_; 
                } shift (@row); 
                $count++; $table->add(@row); $ARRAYQUERY{$count} = [@row];
            } close (IN);


            if ($output) { #if output file is specified, else, result will be printed to the screen
                $outfile = @{ open_unique($output) }[1];
                open (OUT, ">$outfile") or die "ERROR:\t Output file $output can be not be created\n";
                print OUT join("\t", @header),"\n";
                foreach my $row (sort {$a <=> $b} keys %ARRAYQUERY) {
                    no warnings 'uninitialized';
                    print OUT join("\t", @{$ARRAYQUERY{$row}}),"\n";
                } close OUT;
            } else {
                unless ($log) { printerr $table-> render, "\n"; } #print display
            }
            unless ($log) { $verbose and printerr "NOTICE:\t Summary: $count rows in result\n"; }
        } else {
            unless ($log) { printerr "NOTICE:\t No Results based on search criteria: '$query' in '$querynosql' \n"; }
        }
         `rm -rf $nosql`;
    } else { #end of NoSQL query option
        
        $dbh = mysql($all_details{'MySQL-databasename'}, $all_details{'MySQL-username'}, $all_details{'MySQL-password'}); #connect to mysql
        $sth = $dbh->prepare($query); $sth->execute() or exit;

        $table = Text::TabularDisplay->new( @{ $sth->{NAME_uc} } );#header
        @header = @{ $sth->{NAME_uc} };
        while (my @row = $sth->fetchrow_array()) {
            $count++; $table->add(@row); $ARRAYQUERY{$count} = [@row];
        }    
        unless ($count == 0){
            if ($output) { #if output file is specified, else, result will be printed to the screen
                $outfile = @{ open_unique($output) }[1];
                open (OUT, ">$outfile") or die "ERROR:\t Output file $output can be not be created\n";
                print OUT join("\t", @header),"\n";
                foreach my $row (sort {$a <=> $b} keys %ARRAYQUERY) {
                    no warnings 'uninitialized';
                    print OUT join("\t", @{$ARRAYQUERY{$row}}),"\n";
                } close OUT;
            } else {
                unless ($log) { printerr $table-> render, "\n"; } #print display
            }
            unless ($log) { $verbose and printerr "NOTICE:\t Summary: $count rows in result\n"; }
        } else { unless ($log) { printerr "NOTICE:\t No Results based on search criteria: '$query' \n"; } }
    } #end of MySQL query option
} #end of user query module

if ($dbdata){ #if db 2 data mode selected
    no warnings 'uninitialized';
    if ($avgexp){ #looking at average fpkms
        $fastbit = fastbit($all_details{'FastBit-path'}, $all_details{'FastBit-foldername'});  #connect to fastbit
        my $gfastbit = $fastbit."/gene-information";
        $count = 0;
        undef %ARRAYQUERY;
        #making sure required attributes are specified.
        unless ($log){
            if ($extpm) { $verbose and printerr "TASK:\t Average TPM Values of Individual Genes\n"; }
            else { $verbose and printerr "TASK:\t Average FPKM Values of Individual Genes\n"; }
        }
        unless ($gene && $organism){
            unless ($log) {
                unless ($gene) {printerr "ERROR:\t Gene option '-gene' is not specified\n"; }
                unless ($organism) {printerr "ERROR:\t Organism option '-species' is not specified\n"; }
            }
            pod2usage("ERROR:\t Details for -avgexp are missing. Review 'tad-interact.pl -d' for more information");
        }
        $dbh = mysql($all_details{'MySQL-databasename'}, $all_details{'MySQL-username'}, $all_details{'MySQL-password'}); #connect to mysql
        #checking if the organism is in the database
        $organism =~ s/^\s+|\s+$//g;
        $sth = $dbh->prepare("select organism from Animal where organism = '$organism'");$sth->execute(); $found =$sth->fetch();
        unless ($found) { pod2usage("ERROR:\t Organism name '$organism' is not found in database. Consult 'tad-interact.pl -d' for more information"); }
        unless ($log) { $verbose and printerr "NOTICE:\t Organism selected: $organism\n"; }
        
        if ($tissue) {
            my @tissue = split(",", $tissue); undef $tissue; 
            foreach (@tissue) {
                $_ =~ s/^\s+|\s+$//g;
                $sth = $dbh->prepare("select distinct tissue from Sample where tissue = '$_'");$sth->execute(); $found =$sth->fetch();
                unless ($found) { pod2usage("ERROR:\t Tissue name '$_' is not found in database. Consult 'tad-interact.pl -d' for more information"); }
                $tissue .= $_ .",";
            }chop $tissue;
            unless ($log) { $verbose and printerr "NOTICE:\t Tissue(s) selected: $tissue\n"; }
        } else {
            unless ($log) { $verbose and printerr "NOTICE:\t Tissue(s) selected: 'all tissue for $organism'\n"; }
            $sth = $dbh->prepare("select tissue from vw_sampleinfo where organism = '$organism' and genes is not null"); #get samples
            $sth->execute or die "SQL Error: $DBI::errstr\n";
            my $tnumber= 0;
            while (my $row = $sth->fetchrow_array() ) {
                $tnumber++;
                $SAMPLE{$tnumber} = $row;
                $tissue .= $row.",";
            } chop $tissue;
        } #checking sample options
        my @tissue = split(",", $tissue);
        unless ($log) { $verbose and printerr "NOTICE:\t Gene(s) selected: $gene\n"; }
        my @genes = split(",", $gene);
        foreach my $fgene (@genes){
            $fgene =~ s/^\s+|\s+$//g;
            foreach my $ftissue (@tissue) {
                if ($extpm) {
                    @header = ("GENENAME","TISSUE", "MAXIMUM TPM", "AVERAGE TPM", "MINIMUM TPM");
                    `$ibis -d $gfastbit -q 'select genename, max(fpkm), avg(fpkm), min(fpkm), max(tpm), avg(tpm), min(tpm) where genename like "%$fgene%" and tissue = "$ftissue" and organism = "$organism"  and tpm != 0' -o $nosql 2>>$efile`;
                } else {
                    @header = ("GENENAME","TISSUE", "MAXIMUM FPKM", "AVERAGE FPKM", "MINIMUM FPKM");
                    `$ibis -d $gfastbit -q 'select genename, max(fpkm), avg(fpkm), min(fpkm), max(tpm), avg(tpm), min(tpm) where genename like "%$fgene%" and tissue = "$ftissue" and organism = "$organism" and fpkm != 0' -o $nosql 2>>$efile`;
                }
                $table = Text::TabularDisplay->new( @header );
                my $found = `head -n 1 $nosql`;
                if (length($found) > 1) {
                    open(IN,"<",$nosql);
                    while (<IN>){
                        chomp;
                        my ($genename,$fmax,$favg,$fmin,$tmax,$tavg,$tmin) = split (/\, /, $_, 7);
                        $genename =~ s/^'|'$|^"|"$//g; #removing the quotation marks from the words
                        if ($extpm) {
                            @row = ($genename,$ftissue, $tmax, $tavg, $tmin);
                        } else {
                            @row = ($genename,$ftissue, $fmax, $favg, $fmin);
                        }
                        $count++;
                        $ARRAYQUERY{$genename}{$ftissue} = [@row];
                    } close (IN); `rm -rf $nosql`;
                } else {
                    unless ($log) { printerr "NOTICE:\t No Results found with gene '$fgene'\n"; }
                }
            }
        }
        unless ($count == 0) {
            if ($output) { #if output file is specified, else, result will be printed to the screen
                $outfile = @{ open_unique($output) }[1];
                open (OUT, ">$outfile") or die "ERROR:\t Output file $output can be not be created\n";
                print OUT join("\t", @header),"\n";
                foreach my $a (sort keys %ARRAYQUERY){
                    foreach my $b (sort keys % { $ARRAYQUERY{$a} }){
                        print OUT join("\t", @{$ARRAYQUERY{$a}{$b}}),"\n";
                    }
                } close OUT;
            } else {
                foreach my $a (sort keys %ARRAYQUERY){
                    foreach my $b (sort keys % { $ARRAYQUERY{$a} }){
                        $table->add(@{$ARRAYQUERY{$a}{$b}});
                    }
                } 
                unless ($log) { printerr $table-> render, "\n"; }#print display
            }    
            unless ($log) { $verbose and printerr "NOTICE:\t Summary: $count rows in result\n"; }
        } else { unless ($log) { printerr "\nNOTICE:\t No Results based on search criteria: '$gene' \n"; } }
    } #end of avgexp module
    
    if ($genexp){ #looking at gene expression per sample
        `mkdir -p tadtmp/`;
        $count = 0;
        #making sure required attributes are specified.
        unless ($log){
            if ($extpm) { $verbose and printerr "TASK:\t Gene Expression (TPM) of Individual Genes\n"; }
            else { $verbose and printerr "TASK:\t Gene Expression (FPKM) information across Samples\n"; }
        }
        unless ($organism){
            unless ($log) { printerr "ERROR:\t Organism option '-species' is not specified\n"; }
            pod2usage("ERROR:\t Details for -genexp are missing. Review 'tad-interact.pl -e' for more information");
        }
        $dbh = mysql($all_details{'MySQL-databasename'}, $all_details{'MySQL-username'}, $all_details{'MySQL-password'}); #connect to mysql
        $fastbit = fastbit($all_details{'FastBit-path'}, $all_details{'FastBit-foldername'});  #connect to fastbit
        my $gfastbit = $fastbit."/gene-information";
        #checking if the organism is in the database
        $organism =~ s/^\s+|\s+$//g;
        $sth = $dbh->prepare("select organism from Animal where organism = '$organism'");$sth->execute(); $found =$sth->fetch();
        unless ($found) { pod2usage("ERROR:\t Organism name '$organism' is not found in database. Consult 'tad-interact.pl -e' for more information"); }
        unless ($log) { $verbose and printerr "NOTICE:\t Organism selected: $organism\n"; }
        #checking if sample is in the database
        if ($sample) {
            my @sample = split(",", $sample); undef $sample; 
            foreach (@sample) {
                $_ =~ s/^\s+|\s+$//g;
                $sth = $dbh->prepare("select distinct sampleid from Sample where sampleid = '$_'");$sth->execute(); $found =$sth->fetch();
                unless ($found) { pod2usage("ERROR:\t Sample ID '$_' is not in the database. Consult 'tad-interact.pl -e' for more information"); }
                $sample .= $_ .",";
            }chop $sample;
            unless ($log) { $verbose and printerr "NOTICE:\t Sample(s) selected: $sample\n"; }
        } else {
            unless ($log) { $verbose and printerr "NOTICE:\t Sample(s) selected: 'all samples for $organism'\n"; }
            $sth = $dbh->prepare("select sampleid from vw_sampleinfo where organism = '$organism' and genes is not null"); #get samples
            $sth->execute or die "SQL Error: $DBI::errstr\n";
            my $snumber= 0;
            while (my $row = $sth->fetchrow_array() ) {
                $snumber++;
                $SAMPLE{$snumber} = $row;
                $sample .= $row.",";
            } chop $sample;
        } #checking sample options
        @headers = split(",", $sample);
        if ($extpm){
            $syntax = "select genename, tpm, sampleid, chrom, start, stop where tpm != 0 and";
        } else {
            $syntax = "select genename, fpkm, sampleid, chrom, start, stop where fpkm != 0 and";
        }
        if ($gene) {
            my @genes = split(",", $gene); undef $gene;
            foreach (@genes){
                $_ =~ s/^\s+|\s+$//g;
                $gene .= $_.",";
            } chop $gene;
            unless ($log) { $verbose and printerr "NOTICE:\t Gene(s) selected: '$gene'\n"; }
        }
        else {
            unless ($log) { $verbose and printerr "NOTICE:\t Gene(s) selected: 'all genes'\n"; }
        }
        
        unless ($log) { printerr "NOTICE:\t Processing Gene Expression for each library ."; }
        foreach my $header (@headers){ 
            unless ($log) { printerr "."; }
            my $newsyntax;

            if ($gene) {
                my @genes = split(",", $gene);
                foreach (@genes){
                    $_ =~ s/^\s+|\s+$//g;
                    $newsyntax = $syntax." genename like '%$_%' and sampleid = '$header' ORDER BY geneid desc;";
                    `$ibis -d $gfastbit -q "$newsyntax" -o $nosql 2>>$efile`;
                    
                    open(IN,"<",$nosql);
                    while (<IN>){
                        chomp;
                        my ($geneid, $fpkm, $library, $chrom, $start, $stop) = split /\, /; 
                        $geneid =~ s/^'|'$|^"|"$//g; $library =~ s/^'|'$|^"|"$//g; $chrom =~ s/^'|'$|^"|"$//g; #removing quotation marks if applicable
                        $FPKM{"$geneid|$chrom"}{$library} = $fpkm;
                        $CHROM{"$geneid|$chrom"} = $chrom;
                        $POSITION{"$geneid|$chrom"}{$library} = "$start|$stop";
                    } close (IN); `rm -rf $nosql`;
                } # end foreach gene
            } else {
                $newsyntax = $syntax." sampleid = '$header' ORDER BY geneid desc;";
                `$ibis -d $gfastbit -q "$newsyntax" -o $nosql 2>>$efile`;
                
                open(IN,"<",$nosql);
                while (<IN>){ 
                    chomp;
                    my ($geneid, $fpkm, $library, $chrom, $start, $stop) = split /\, /; 
                    $geneid =~ s/^'|'$|^"|"$//g; $library =~ s/^'|'$|^"|"$//g; $chrom =~ s/^'|'$|^"|"$//g; #removing quotation marks if applicable
                    $FPKM{"$geneid|$chrom"}{$library} = $fpkm;
                    $CHROM{"$geneid|$chrom"} = $chrom;
                    $POSITION{"$geneid|$chrom"}{$library} = "$start|$stop";
                } close (IN); `rm -rf $nosql`;
            }
            
        } #end foreach extracting information from the database    
        unless ($log) {
            printerr " Done\n";
            printerr "NOTICE:\t Processing Results ...";
        }
        foreach my $newgene (sort keys %CHROM){ #turning the genes into an array
            if ($newgene =~ /^[\d\w]/){ push @genearray, $newgene;}
        }
        push @VAR, [ splice @genearray, 0, 2000 ] while @genearray; #sub array the genes into a list of 2000
    
        @headers = split(",", $sample);
        foreach (0..$#VAR){ $newfile .= "tadtmp/tmp_".$tmpname."-".$_.".zzz "; } #foreach sub array create a temporary file
        $queue = new Thread::Queue();
        my $builder=threads->create(\&main); #create thread for each subarray into a thread
        push @threads, threads->create(\&processor) for 1..5; #execute 5 threads
        $builder->join; #join threads
        foreach (@threads){$_->join;}
        my $command="cat $newfile >> $tmpout"; #path into temporary output
        system($command);
        `rm -rf tadtmp/`; #remove all temporary files
        unless ($log) { printerr " Done\n"; }
        @header = qw|GENE CHROM|; push @header, @headers;
        $count = `cat $tmpout | wc -l`; chomp $count;
        open my $content,"<",$tmpout; `rm -rf $tmpout`;
        $table = Text::TabularDisplay->new( @header );
        unless ($count == 0) {
            if ($output){
                $outfile = @{ open_unique($output) }[1];
                open (OUT, ">$outfile") or die "ERROR:\t Output file $output can be not be created\n";
                print OUT join("\t", @header),"\n";
                print OUT <$content>;
                close OUT;
            } else {
                while (<$content>){ chomp;$table->add(split "\t"); }
                unless ($log) { printerr $table-> render, "\n"; }#print display
            }
            unless ($log) { $verbose and printerr "NOTICE:\t Summary: $count rows in result\n"; }
        } else { unless ($log) { printerr "\nNOTICE:\t No Results based on search criteria \n"; } }
    } #end of genexp module
    
    if ($chrvar){ #looking at chromosomal variant distribution
        no warnings 'uninitialized';
        undef %SAMPLE; undef %ARRAYQUERY;
        $count = 0;
        #making sure required attributes are specified.
        unless ($log) { $verbose and printerr "TASK:\t Chromosomal Variant Distribution Across Samples\n"; }
        unless ($organism){
            unless ($log) { printerr "ERROR:\t Organism option '-species' is not specified\n"; }
            pod2usage("ERROR:\t Details for -chrvar are missing. Review 'tad-interact.pl -f' for more information");
        }
        $dbh = mysql($all_details{'MySQL-databasename'}, $all_details{'MySQL-username'}, $all_details{'MySQL-password'}); #connect to mysql
        #checking if the organism is in the database
        $organism =~ s/^\s+|\s+$//g;
        $sth = $dbh->prepare("select organism from Animal where organism = '$organism'");$sth->execute(); $found =$sth->fetch();
        unless ($found) { pod2usage("ERROR:\t Organism name '$organism' is not found in database. Consult 'tad-interact.pl -f' for more information"); }
        unless ($log) { $verbose and printerr "NOTICE:\t Organism selected: $organism\n"; }
        #checking if sample is in the database
        if ($sample) {
            my @sample = split(",", $sample); undef $sample; 
            foreach (@sample) {
                $_ =~ s/^\s+|\s+$//g;
                $sth = $dbh->prepare("select distinct sampleid from Sample where sampleid = '$_'");$sth->execute(); $found =$sth->fetch();
                unless ($found) { pod2usage("ERROR:\t Sample ID '$_' is not in the database. Consult 'tad-interact.pl -f' for more information"); }
                $sample .= $_ .",";
            } chop $sample;
            unless ($log) { $verbose and printerr "NOTICE:\t Sample(s) selected: $sample\n"; }
        } else {
            unless ($log) { $verbose and printerr "NOTICE:\t Sample(s) selected: 'all samples for $organism'\n"; }
            $sth = $dbh->prepare("select sampleid from vw_sampleinfo where organism = '$organism' and totalvariants is not null"); #get samples
            $sth->execute or die "SQL Error: $DBI::errstr\n";
            my $snumber= 0; undef $sample;
            while (my $row = $sth->fetchrow_array() ) {
                $snumber++;
                $SAMPLE{$snumber} = $row;
                $sample .= $row.",";
            } chop $sample;
        } #checking sample options
        @headers = split(",", $sample);
        if ($#headers >= 0) {
            $syntax = "select sampleid, chrom, count(*) from VarResult where sampleid in ( ";
            foreach (@headers) { $syntax .= "'$_',"; } chop $syntax; $syntax .= ")";            
            if ($chromosome) {
                my @chromosome = split(",", $chromosome); undef $chromosome;
                $syntax .= " and (";
                foreach (@chromosome) {
                    $_ =~ s/^\s+|\s+$//g;
                    $sth = $dbh->prepare("select distinct chrom from VarResult where chrom = '$_'");$sth->execute(); $found =$sth->fetch();
                    unless ($found) { pod2usage("ERROR:\t Chromosome '$_' is not in the database. Consult 'tad-interact.pl -f' for more information"); }
                    $syntax .= "chrom = '$_' or ";
                    $chromosome .= $_ .",";
                } $syntax = substr($syntax,0, -3); $syntax .= ") "; chop $chromosome;
                unless ($log) { $verbose and printerr "NOTICE:\t Chromosome(s) selected: $chromosome\n"; }
            } else {
                unless ($log) { $verbose and printerr "NOTICE:\t Chromosome(s) selected: 'all chromosomes'\n"; }
            }
            my $endsyntax = "group by sampleid, chrom order by sampleid, length(chrom), chrom";
            my $allsyntax = $syntax.$endsyntax;
            $sth = $dbh->prepare($allsyntax); 
            $sth->execute or die "SQL Error:$DBI::errstr\n";
            my $number = 0;
            while (my ($sampleid, $chrom, $counted) = $sth->fetchrow_array() ) {
                $number++;
                $CHROM{$sampleid}{$number} = $chrom;
                $VARIANTS{$sampleid}{$chrom} = $counted;
            }    
            $allsyntax = $syntax."and variantclass = 'SNV' ".$endsyntax; #counting SNPS
            $sth = $dbh->prepare($allsyntax); 
            $sth->execute or die "SQL Error:$DBI::errstr\n";
            while (my ($sampleid, $chrom, $counted) = $sth->fetchrow_array() ) {
                $SNPS{$sampleid}{$chrom} = $counted;
            }
            $allsyntax = $syntax."and (variantclass = 'insertion' or variantclass = 'deletion') ".$endsyntax; #counting INDELs
            $sth = $dbh->prepare($allsyntax); 
            $sth->execute or die "SQL Error:$DBI::errstr\n";
            while (my ($sampleid, $chrom, $counted) = $sth->fetchrow_array() ) {
                $INDELS{$sampleid}{$chrom} = $counted;
            }
            @header = qw(SAMPLE CHROMOSOME VARIANTS SNPs INDELs);
            $table = Text::TabularDisplay->new(@header);
            my @content;
            foreach my $ids (sort keys %VARIANTS){  
                if ($ids =~ /^[0-9a-zA-Z]/) {
                    foreach my $no (sort {$a <=> $b} keys %{$CHROM{$ids} }) {
                        $count++;
                        my @row = ();
                        push @row, ($ids, $CHROM{$ids}{$no}, $VARIANTS{$ids}{$CHROM{$ids}{$no}});
                        if (exists $SNPS{$ids}{$CHROM{$ids}{$no}}){
                            push @row, $SNPS{$ids}{$CHROM{$ids}{$no}};
                        } else {
                            push @row, "0";
                        }
                        if (exists $INDELS{$ids}{$CHROM{$ids}{$no}}){
                            push @row, $INDELS{$ids}{$CHROM{$ids}{$no}};
                        }
                        else {
                            push @row, "0";
                        }
                        $table->add(@row);
                        $ARRAYQUERY{$count} = [@row];
                    }
                }
            }
            unless ($count == 0) {
                if ($output){
                    $outfile = @{ open_unique($output) }[1];
                    open (OUT, ">$outfile") or die "ERROR:\t Output file $output can be not be created\n";
                    print OUT join("\t", @header),"\n";
                    foreach (sort {$a <=> $b} keys %ARRAYQUERY) { print OUT join("\t",@{$ARRAYQUERY{$_}}), "\n"; }
                    close OUT;
                } else {
                    unless ($log) { printerr $table-> render, "\n"; } #print display
                }
                unless ($log) { $verbose and printerr "NOTICE:\t Summary: $count rows in result\n"; }
            } else { unless ($log) { printerr "\nNOTICE:\t No Results based on search criteria \n"; } }
        } else { unless ($log) { printerr "\nNOTICE:\t No Results based on search criteria \n"; } }
    } #end of chrvar module
    
    if ($varanno){ #looking at variants 
        undef %SAMPLE; undef %ARRAYQUERY; undef $status;
        $count = 0;
        #making sure required attributes are specified.
        unless ($log) { $verbose and printerr "TASK:\t Associated Variant Annotation Information\n"; }
        unless ($organism){
            unless ($log) { printerr "ERROR:\t Organism option '-species' is not specified\n"; }
            pod2usage("ERROR:\t Details for -varanno are missing. Review 'tad-interact.pl' for more information");
        }
        unless ($log) {
            if ($gene) { $verbose and printerr "SUBTASK: Gene-associated Variants with Annotation Information\n"; }
            if ($chromosome) { $verbose and printerr "SUBTASK: Chromosomal region-associated Variants and Annotation Information\n"; }
        }
        $dbh = mysql($all_details{'MySQL-databasename'}, $all_details{'MySQL-username'}, $all_details{'MySQL-password'}); #connect to mysql
        $fastbit = fastbit($all_details{'FastBit-path'}, $all_details{'FastBit-foldername'});  #connect to fastbit
        my $vfastbit = $fastbit."/variant-information";
        $organism =~ s/^\s+|\s+$//g;
        $sth = $dbh->prepare("select organism from Animal where organism = '$organism'");$sth->execute(); $found =$sth->fetch();
        unless ($found) { pod2usage("ERROR:\t Organism name '$organism' is not found in database. Consult 'tad-interact.pl -f' for more information"); }
        unless ($log) { $verbose and printerr "NOTICE:\t Organism selected: $organism\n"; }
        my $number = 0;
        $sth = $dbh->prepare("select group_concat(distinct a.nosql) from VarSummary a join vw_sampleinfo b on a.sampleid = b.sampleid where b.organism = '$organism' and a.nosql is not null group by a.nosql");$sth->execute(); $found =$sth->fetch();
        unless ($found) {
            $vcfsyntax = "select sampleid, chrom, position, refallele, altallele, quality, consequence, genename, geneid, feature, transcript, genetype, proteinposition, aachange, codonchange, dbsnpvariant, variantclass, zygosity, tissue from vw_vvcf where organism='$organism'";
        } else {
            $syntax = "$ibis -d $vfastbit -q \"select chrom,position,refallele,altallele,variantclass,consequence,group_concat(genename),group_concat(dbsnpvariant), group_concat(sampleid) where organism='$organism'";
            $vcfsyntax = "$ibis -d $vfastbit -q \"select sampleid, chrom, position, quality, proteinposition, refallele, altallele, consequence, genename, geneid, feature, transcript, genetype, aachange,  codonchange, dbsnpvariant, variantclass, zygosity, tissue where organism='$organism'";
        } #the toggle between mysql and fastbit
        unless ($gene) {
            if ($chromosome){
                my ($start, $stop) = (0,0);
                my @chromosomes = split(",", $chromosome); undef $chromosome;
                foreach (@chromosomes){ $_ =~ s/^\s+|\s+$//g; $chromosome .= $_.","; } chop $chromosome;
                unless ($log) { $verbose and printerr "NOTICE:\t Chromosome(s) selected: '$chromosome'\n"; }
                $chrheader = $chromosome;
                if ($#chromosomes == 0) {
                    if ($region){
                        $syntax .= " and chrom = '$chromosomes[0]'";
                        $vcfsyntax .= " and chrom = '$chromosomes[0]'";
                        if ($region =~ /\-/) {
                            ($start, $stop) = split("-", $region);
                            $syntax .= " and position between $start and $stop";
                            $vcfsyntax .= " and position between $start and $stop";
                            $chrheader .= ":$start\-$stop";
                            unless ($log) { $verbose and printerr "NOTICE:\t Region: between $start and $stop\n"; }
                        } else {
                            $start = $region-1500; $stop = $region+1500;
                            $syntax .= " and position between ". $start." and ". $stop;
                            $vcfsyntax .= " and position between ". $start." and ". $stop;
                            $chrheader .= ":$start\-$stop";
                            unless ($log) { $verbose and printerr "NOTICE:\t Region: 3000bp region of $region\n"; }
                        }
                        unless ($found) { # if no nosql output
                            $syntax = "call usp_vchrposition(\"".$organism."\",\"".$chromosomes[0]."\",\"".$start."\",\"".$stop."\")";
                            $sth = $dbh->prepare($syntax);
                            $sth->execute or die "SQL Error: $DBI::errstr\n";
                            my $newcount= 0;
                            while (my @row = $sth->fetchrow_array() ) {
                                $count++; $newcount++;
                                if ($row[5] =~ /^-/){ $row[5] = ''; }
                                $SAMPLE{$row[0]}{$row[1]}{$row[5]} = [@row];
                            }
                            unless ($log) { unless ($newcount > 0) { printerr "NOTICE:\t No variants are associated with chromosomal region '$chrheader'\n"; } } #if gene is in the database     
                        }
                    } #end if region
                    else { # if only one chromosome is specified and no region
                        unless ($found) { # if no nosql output 
                            $syntax = "call usp_vchrom(\"".$organism."\",\"".$chromosomes[0]."\")";
                            $sth = $dbh->prepare($syntax);
                            $sth->execute or die "SQL Error: $DBI::errstr\n";
                            my $newcount= 0;
                            while (my @row = $sth->fetchrow_array() ) {
                                $count++; $newcount++;
                                if ($row[5] =~ /^-/){ $row[5] = ''; }
                                $SAMPLE{$row[0]}{$row[1]}{$row[5]} = [@row];
                            }
                            unless ($log) { unless ($newcount > 0) { printerr "NOTICE:\t No variants are associated with chromosome '$chromosomes[0]'\n"; } } #if gene is in the database     
                        } else {
                            $syntax .= " and chrom = '$chromosomes[0]'";
                            $vcfsyntax .= " and chrom = '$chromosomes[0]'";
                        }
                    }
                } else { #to make sure only one chromosome is specified, or else
                    if ($found) { $syntax .= " and ("; }
                    $vcfsyntax .= " and (";
                    foreach (@chromosomes) {
                        if ($found) {
                            $syntax .= "chrom = '$_' or ";
                        } else {
                            $syntax = "call usp_vchrom(\"".$organism."\",\"".$_."\")";
                            $sth = $dbh->prepare($syntax);
                            $sth->execute or die "SQL Error: $DBI::errstr\n";
                            my $newcount=0;
                            while (my @row = $sth->fetchrow_array() ) {
                                $count++; $newcount++;
                                if ($row[5] =~ /^-/){ $row[5] = ''; }
                                $SAMPLE{$row[0]}{$row[1]}{$row[5]} = [@row];
                            }
                            unless ($log) { unless ($newcount > 0) { printerr "NOTICE:\t No variants are associated with chromosome '$_'\n"; } } #if gene is in the database     
                        }
                        $vcfsyntax .= "chrom = '$_' or ";
                    }
                    $syntax = substr($syntax, 0, -3); $syntax .= ") ";
                    $vcfsyntax = substr($vcfsyntax, 0, -3); $vcfsyntax .= ") ";
                }
            } #end if chromosome
            else {
                unless ($log) { $verbose and printerr "NOTICE:\t Chromosome(s) selected: 'all chromosomes'\n"; $chrheader="all chromosomes"; }
                unless ($found){
                    $syntax = "call usp_vall(\"".$organism."\")";
                    $sth = $dbh->prepare($syntax);
                    $sth->execute or die "SQL Error: $DBI::errstr\n";
                    while (my @row = $sth->fetchrow_array() ) {
                        $count++;
                        if ($row[5] =~ /^-/){ $row[5] = ''; }
                        $SAMPLE{$row[0]}{$row[1]}{$row[5]} = [@row];
                    }
                }
            }
            if ($found) {
                $syntax .= "\" -o $nosql";
                $vcfsyntax .= "\" -o $nosql";
                if ($vcf) {
                    `$vcfsyntax 2>> $efile`;
                    open(IN,'<',$nosql); my @nosqlcontent = <IN>; close IN; `rm -rf $nosql`;
                    foreach (@nosqlcontent) {
                        chomp; $count++; 
                        my @arraynosqlA = split (",",$_,6); foreach (@arraynosqlA[0..4]) { $_ =~ s/"//g; $_ =~ s/^\s+|\s+$//g; } 
                        if ($arraynosqlA[4] == 0) {$arraynosqlA[4] = ""};
                        my @arraynosqlB = split("\", \"", $arraynosqlA[$#arraynosqlA]); foreach (@arraynosqlB) { $_ =~ s/"//g ; $_ =~ s/^\s+|\s+$//g; $_ =~ s/NULL//g;}
                        push my @row, (@arraynosqlA[0..2], @arraynosqlB[0..1], $arraynosqlA[3], $arraynosqlB[2], @arraynosqlB[3..7], $arraynosqlA[4],@arraynosqlB[8..$#arraynosqlB]);
                        PROCESS(@row);
                    }
                } else {
                    `$syntax 2>> $efile`;
                    open(IN,'<',$nosql); my @nosqlcontent = <IN>; close IN; `rm -rf $nosql`;
                    foreach (@nosqlcontent) {
                        chomp; $count++;
                        my @arraynosqlA = split (",",$_,3); foreach (@arraynosqlA[0..1]) { $_ =~ s/"//g;}
                        my @arraynosqlB = split("\", \"", $arraynosqlA[2]); foreach (@arraynosqlB) { $_ =~ s/"//g ; $_ =~ s/NULL/-/g;}
                        my @arraynosqlC = uniq(sort(split(", ", $arraynosqlB[4]))); if ($#arraynosqlC > 0 && $arraynosqlC[0] =~ /^-/){ shift @arraynosqlC; }
                        my @arraynosqlD = uniq(sort(split(", ", $arraynosqlB[5]))); if ($#arraynosqlD > 0 && $arraynosqlD[0] =~ /^-/){ shift @arraynosqlD; }
                        push my @row, @arraynosqlA[0..1], @arraynosqlB[0..3], join(",", @arraynosqlC) , join(",", @arraynosqlD), join (",", uniq(sort(split (", ", $arraynosqlB[6]))));
                        $SAMPLE{$arraynosqlA[0]}{$arraynosqlA[1]}{$arraynosqlB[3]} = [@row];
                    }
                }
            } else {
                if ($vcf) {
                    $sth = $dbh->prepare($vcfsyntax);
                    $sth->execute or die "SQL Error: $DBI::errstr\n";
                    while (my @row = $sth->fetchrow_array() ) {
                        $count++;
                        no warnings 'uninitialized';
                        foreach (@row) { if ($_ =~ /^-/){ $row[6] = ''; } }
                        PROCESS(@row);
                    }
                }
            } #toggle between mysql and fastbit
            unless ($vcf) {
                foreach my $aa (natsort keys %SAMPLE){
                    foreach my $bb (sort {$a <=> $b} keys % {$SAMPLE{$aa} }){
                        foreach my $cc (sort {$a cmp $b || $a <=> $b} keys % {$SAMPLE{$aa}{$bb} }){
                            $number++;
                            $ARRAYQUERY{$number} = [@{ $SAMPLE{$aa}{$bb}{$cc} }];
                        }
                    }
                } #end parsing the results to arrayquery
            }
        } #end unless gene
        else {
            my @genes = split(",", $gene); undef $gene;
            foreach (@genes){ $_ =~ s/^\s+|\s+$//g; $gene .= $_.","; } chop $gene;
            unless ($log) { $verbose and printerr "NOTICE:\t Gene(s) selected: '$gene'\n"; }
            foreach my $subgene (@genes) {
                if ($found) { 
                    my $gsyntax = $syntax." and genename like '%".uc($subgene)."%'\" -o $nosql";
                    `$gsyntax 2>> $efile`;
                    open(IN,'<',$nosql); my @nosqlcontent = <IN>; close IN; `rm -rf $nosql`;
                    if ($#nosqlcontent < 0) {$status .= "NOTICE:\t No variants are associated with gene '$subgene' \n";}
                    else {
                        foreach (@nosqlcontent) {
                            chomp; $count++;
                             $syntax = "$ibis -d $vfastbit -q \"select chrom,position,refallele,altallele,variantclass,consequence,group_concat(genename),group_concat(dbsnpvariant), group_concat(sampleid) where organism='$organism'";
                            my @arraynosqlA = split (",",$_,3); foreach (@arraynosqlA[0..1]) { $_ =~ s/"//g;}
                            my @arraynosqlB = split("\", \"", $arraynosqlA[2]); foreach (@arraynosqlB) { $_ =~ s/"//g ; $_ =~ s/NULL/-/g;}
                            push my @row, @arraynosqlA[0..1], @arraynosqlB[0..3], join(",", uniq(sort(split(", ", $arraynosqlB[4])))) , join(",", uniq(sort(split(", ", $arraynosqlB[5])))), join (",", uniq(sort(split (", ", $arraynosqlB[6]))));
                            $SAMPLE{$subgene}{$arraynosqlA[0]}{$arraynosqlA[1]}{$arraynosqlB[3]} = [@row];
                        }
                    }
                } else {
                    my $newcount = 0;
                    $syntax = "call usp_vgene(\"".$organism."\",\"".$subgene."\")"; 
                    $sth = $dbh->prepare($syntax);
                    $sth->execute or die "SQL Error: $DBI::errstr\n";
                    while (my @row = $sth->fetchrow_array() ) {
                         $count++; $newcount++;
                        $SAMPLE{$subgene}{$row[0]}{$row[1]}{$row[5]} = [@row];
                    }
                    unless ($log) { unless ($newcount > 0) { printerr "NOTICE:\t No variants are associated with gene '$subgene'\n"; } }#if gene is in the database
                } #if not in nosql
            }
            foreach my $aa (keys %SAMPLE){ #getting content to output
                foreach my $bb (natsort keys % {$SAMPLE{$aa} }){
                    foreach my $cc (sort {$a <=> $b} keys % {$SAMPLE{$aa}{$bb} }) {
                        foreach my $dd (sort keys % {$SAMPLE{$aa}{$bb}{$cc} }) {
                            $number++;
                            $ARRAYQUERY{$number} = [@{ $SAMPLE{$aa}{$bb}{$cc}{$dd} }];
                        }
                    }
                }
            } #end parsing the results to arrayquery
        } #end if gene
        @header = qw(Chrom Position Refallele Altallele Variantclass Consequence Genename Dbsnpvariant Sampleid);
        tr/a-z/A-Z/ for @header;
        $table = Text::TabularDisplay->new(@header); #header
        
        unless ($count == 0) {
            if ($output) { #if output file is specified, else, result will be printed to the screen
                $outfile = @{ open_unique($output) }[1];
                open (OUT, ">$outfile") or die "ERROR:\t Output file $output can be not be created\n";
                unless ($vcf) {
                    print OUT join("\t", @header),"\n";
                    foreach my $a (sort {$a <=> $b} keys %ARRAYQUERY){
                        no warnings 'uninitialized';
                        print OUT join("\t", @{$ARRAYQUERY{$a}}),"\n";
                    } 
                } else {
                    SORTER();
                    MTD();
                    #our $headerinfo = HEADER();
                    print OUT HEADER($organism, $chrheader); #$headerinfo;
                    foreach my $chrom (natsort keys %NEWREF) {
                        foreach my $position (sort {$a<=> $b} keys %{$NEWREF{$chrom}}) {
                            foreach my $ref (sort {$a cmp $b} keys %{$NEWREF{$chrom}{$position}}) {
                                print OUT "chr",$chrom,"\t",$position,"\t",$NEWDBSNP{$chrom}{$position}{$ref},"\t",$NEWREF{$chrom}{$position}{$ref},"\t";
                                print OUT $NEWALT{$chrom}{$position}{$ref},"\t",$NEWQUAL{$chrom}{$position}{$ref},"\tPASS\t";
                                if (exists $NEWCSQ{$chrom}{$position}{$ref}) {
                                    $NEWCSQ{$chrom}{$position}{$ref} =~ s/0O0O0O/\*/g;
                                    print OUT "CSQ=",$NEWCSQ{$chrom}{$position}{$ref}, ";";
                                }
                                print OUT "MTD=",$MTD{$chrom}{$position}{$ref},"\tGT\t",$NEWGT{$chrom}{$position}{$ref};
                                print OUT "\n";
                            }
                        }
                    }    
                } close OUT;
            } else {
                foreach my $a (sort {$a <=> $b} keys %ARRAYQUERY){
                    $table->add(@{$ARRAYQUERY{$a}});
                }
                unless ($log) { printerr $table-> render, "\n"; }#print display
            }    
            unless ($log) { $verbose and printerr "NOTICE:\t Summary: $count rows in result\n"; }
        } else { unless ($log) { printerr "\nNOTICE:\t No Results based on search criteria \n"; } }
    } #end of varanno module
} #end of db2data module
#output: the end
unless ($log) { 
    printerr "-----------------------------------------------------------------\n";
    printerr $status;
    unless ($count == 0) { if ($output) { printerr "NOTICE:\t Successful export of user report to '$outfile'\n"; } }
    printerr ("NOTICE:\t Summary in log file $efile\n");
    printerr "-----------------------------------------------------------------\n";
    print LOG "TransAtlasDB Completed:\t", scalar(localtime),"\n";
    close (LOG);
} else {
    `rm -rf $efile`;
}
#--------------------------------------------------------------------------------

sub processArguments {
    my @commandline = @ARGV;
    GetOptions('verbose|v'=>\$verbose, 'help|h'=>\$help, 'man|m'=>\$man, 'query=s'=>\$query, 'nosql=s'=>\$querynosql, 'db2data'=>\$dbdata, 'o|output'=>\$output,'w'=>\$log,
                         'avgexp'=>\$avgexp, 'gene=s'=>\$gene, 'tissue=s'=>\$tissue, 'species=s'=>\$organism, 'genexp'=>\$genexp, 'fpkm'=>\$exfpkm,
                         'tpm'=>\$extpm, 'vcf'=>\$vcf, 'samples|sample=s'=>\$sample, 'chrvar'=>\$chrvar, 'chromosome=s'=>\$chromosome,
                         'varanno'=>\$varanno,'region=s'=>\$region) or pod2usage ();

    $help and pod2usage (-verbose=>1, -exitval=>1, -output=>\*STDOUT);
    $man and pod2usage (-verbose=>2, -exitval=>1, -output=>\*STDOUT);  
    pod2usage(-msg=>"ERROR:\t Invalid syntax specified, choose -query or -db2data.") unless ( $query || $dbdata);
    pod2usage(-msg=>"ERROR:\t Invalid syntax specified @commandline") if (($query && $dbdata)|| ($avgexp && $genexp) || ($gene && $chromosome));
    if ($dbdata) { pod2usage(-msg=>"ERROR:\t Invalid syntax specified @commandline, choose -avgexp or -genexp or -chrvar or -varanno") unless ($avgexp || $genexp || $chrvar || $varanno); }
    if ($vcf) {
        pod2usage(-msg=>"ERROR:\t VCF output is not configured for specific genes, remove -gene option") if ($varanno && $gene);
        pod2usage(-msg=>"ERROR:\t VCF output is not configured @commandline") unless ($varanno && ! $gene);
    }
    if ($vcf) { pod2usage("ERROR:\t Syntax error. Specify -output <filename>") unless ($output); }
    @ARGV<=1 or pod2usage("Syntax error");
    if ($output) {
        @ARGV==1 or pod2usage("ERROR:\t Syntax error. Specify the output filename");
        $output = $ARGV[0];
        my ($base,$path) = fileparse($output,qr{\.\S+});
        $output = $path.$base."\.txt";
        $output = $path.$base."\.vcf" if ($vcf);
    }
    
  $verbose ||=0;
  my $get = dirname(abs_path $0); #get source path
  $connect = $get.'/.connect.txt';
  #setup log file
    $efile = @{ open_unique("db.tad_status.log") }[1]; `rm -rf $efile`;
    $tmpout = @{ open_unique(".export.txt") }[1]; `rm -rf $tmpout`;
    $nosql = @{ open_unique(".nosqlexport.txt") }[1]; `rm -rf $nosql`;
  unless ($log) {
    open(LOG, ">>", $efile) or die "\nERROR:\t cannot write LOG information to log file $efile $!\n";
    print LOG "TransAtlasDB Version:\t",$VERSION,"\n";
    print LOG "TransAtlasDB Information:\tFor questions, comments, documentation, bug reports and program update, please visit $default \n";
    print LOG "TransAtlasDB Command:\t $0 @commandline\n";
    print LOG "TransAtlasDB Started:\t", scalar(localtime),"\n";
  }
}

sub main {
    no warnings;
    foreach my $count (0..$#VAR) {
        my $namefile = "tadtmp/tmp_".$tmpname."-".$count.".zzz";
        push $VAR[$count], $namefile;
        while(1) {
            if ($queue->pending() <100) {
                $queue->enqueue($VAR[$count]);
                last;
            }
        }
    }
    foreach(1..5) { $queue-> enqueue(undef); }
}

sub processor {
    my $query;
    while ($query = $queue->dequeue()){
        collectsort(@$query);
    }
}

sub collectsort{
    my $file = pop @_;
    open(OUT2, ">$file");
    foreach (@_){    
        sortposition($_);
    }
    foreach my $genename (sort @_){ 
        if ($genename =~ /^\S/){
            my ($realstart,$realstop) = split('\|',$REALPOST{$genename},2);
            my $realgenes = (split('\|',$genename))[0];
            print OUT2 $realgenes,"\t";
            if ($CHROM{$genename} =~ /NULL$/) { print OUT2 "\t"; }
            else { print OUT2 $CHROM{$genename}."\:".$realstart."\-".$realstop."\t"; }
            foreach my $lib (0..$#headers-1){
                if (exists $FPKM{$genename}{$headers[$lib]}){
                    print OUT2 "$FPKM{$genename}{$headers[$lib]}\t";
                }
                else {
                    print OUT2 "0\t";
                }
            }
            if (exists $FPKM{$genename}{$headers[$#headers]}){
                print OUT2 "$FPKM{$genename}{$headers[$#headers]}\n";
            }
            else {
                print OUT2 "0\n";
            }
        }
  }
}

sub sortposition {
  my $genename = $_[0];
  my $status = "nothing";
    my @newstartarray; my @newstoparray;
    foreach my $libest (sort keys % {$POSITION{$genename}} ) {
        my ($astart, $astop, $status) = VERDICT(split('\|',$POSITION{$genename}{$libest},2));
    push @newstartarray, $astart;
        push @newstoparray, $astop;
        if ($status eq "reverse"){
            $realstart = (sort {$b <=> $a} @newstartarray)[0];
            $realstop = (sort {$a <=> $b} @newstoparray)[0];
        } else {
            $realstart = (sort {$a <=> $b} @newstartarray)[0];
            $realstop = (sort {$b <=> $a} @newstoparray)[0];    
        }
        $REALPOST{$genename} = "$realstart|$realstop";
    }
}

sub VERDICT {
    my (@array) = @_;
    my $status = "nothing";
    my (@newstartarray, @newstoparray);
    if ($array[0] > $array[1]) {
        $status = "reverse";
    }
    elsif ($array[0] < $array[1]) {
        $status = "forward";
    }
    return $array[0], $array[1], $status;
}

sub HEADER {
#header information
    no warnings 'uninitialized';
    my ($organism, $chrheader) = (@_);
  my $headerinfo = <<"ENDOFFILE";
##fileformat=VCFv4.1
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
##DBmodel="TransAtlasDB vcf export" organism="$organism" chromosome="$chrheader"
##INFO=<ID=MTD,Number=.,Type=String,Description="Metadata information from TransAtlasDB. Format:Library|Tissue|Quality|Genotype">
$consequenceheader#CHROM    POS    ID    REF    ALT    QUAL    FILTER    INFO    FORMAT    Label
ENDOFFILE
  return $headerinfo;
}

sub PROCESS {
    my @line = @_; 
    $line[1] = substr($line[1],3);
    $TISSUE{$line[0]} = lc($line[18]);
    $REF{$line[1]}{$line[2]}{$line[3]}{$line[0]} = $line[3];
    $ALT{$line[1]}{$line[2]}{$line[3]}{$line[0]} = $line[4];
    $QUAL{$line[1]}{$line[2]}{$line[3]}{$line[0]} = $line[5];
    if ($line[6]) {
        $consequenceheader = '##INFO=<ID=CSQ,Number=.,Type=String,Description="Consequence annotations. Format:Consequence|SYMBOL|Gene|Feature_type|Feature|BIOTYPE|Protein_position|Amino_acids|Codons|Existing_variation|VARIANT_CLASS">'."\n";
        no warnings 'uninitialized'; $line[13] =~ s/\*/0O0O0O/g;
        my $joint = "$line[6]|$line[7]|$line[8]|$line[9]|$line[10]|$line[11]|$line[12]|$line[13]|$line[14]|$line[15]|$line[16]";
        if (exists $CSQ{$line[1]}{$line[2]}{$line[3]}{$line[0]}) {
        $number{$line[1]}{$line[2]}{$line[3]}{$line[0]} = $number{$line[1]}{$line[2]}{$line[3]}{$line[0]}++;
        $ODACSQ{$line[1]}{$line[2]}{$line[3]}{$line[0]}{$number{$line[1]}{$line[2]}{$line[3]}{$line[0]}} = $joint;
        $CSQ{$line[1]}{$line[2]}{$line[3]}{$line[0]} =  "$CSQ{$line[1]}{$line[2]}{$line[3]}{$line[0]},$joint";
        }
        else {
            $number{$line[1]}{$line[2]}{$line[3]}{$line[0]}= 1;
            $ODACSQ{$line[1]}{$line[2]}{$line[3]}{$line[0]}{1} = $joint;
            $CSQ{$line[1]}{$line[2]}{$line[3]}{$line[0]} =  $joint;
        }
    }
    my $verdict = undef;
    if ($line[17] =~ /^homozygous/){
        $verdict = '1/1';
    }
    elsif ($line[17] =~ /alternate/){
        $verdict = '1/2';
    }
    elsif ($line[17] =~ /^heterozygous$/){
        $verdict = '0/1';
    }
    else {die "zygosity is blank\n";}
    if (exists $GT{$line[1]}{$line[2]}{$line[3]}{$line[0]}) {
        unless ($GT{$line[1]}{$line[2]}{$line[3]}{$line[0]} =~ $verdict){
            die "Genotype information is different: $verdict is not ",$GT{$line[1]}{$line[2]}{$line[3]}{$line[0]},"contact $AUTHOR\n";
        }
    }
    else {
        $GT{$line[1]}{$line[2]}{$line[3]}{$line[0]} = $verdict;
    }
    no warnings 'uninitialized';
    if (length $line[15] < 1){ $line[15] = '.' ;}
    #if ($line[15]) { if (length $line[15] < 1){ $line[15] = '.' ;} } else { $line[15] = '.' ; }
    if (exists $DBSNP{$line[1]}{$line[2]}{$line[3]}{$line[0]}) {
        unless ($DBSNP{$line[1]}{$line[2]}{$line[3]}{$line[0]} =~ $line[15]){
            die "DBSNPs information is different: $line[15] is not ",$DBSNP{$line[1]}{$line[2]}{$line[3]}{$line[0]},"contact $AUTHOR\n";
        }
    }
    else {
        $DBSNP{$line[1]}{$line[2]}{$line[3]}{$line[0]} = $line[15];
    }
}


sub SORTER {
  #SORT ALLELES
  foreach my $chrom (natsort keys %REF) {
    foreach my $position (sort {$a <=> $b} keys %{$REF{$chrom}}) {
      foreach my $ref (sort {$a cmp $b} keys %{$REF{$chrom}{$position}}) {
        foreach my $library (sort {$a cmp $b || $a <=> $b } keys %{$REF{$chrom}{$position}{$ref}}) {
          if (exists $subref{$chrom}{$position}{$ref}){
            unless ($subref{$chrom}{$position}{$ref} =~ $REF{$chrom}{$position}{$ref}{$library}){
              $subref{$chrom}{$position}{$ref}= $subref{$chrom}{$position}{$ref}.",".$REF{$chrom}{$position}{$ref}{$library};
            }
          }
          else {
            $subref{$chrom}{$position}{$ref}= $REF{$chrom}{$position}{$ref}{$library};
          }
        }
        foreach my $library (sort {$a cmp $b || $a <=> $b} keys %{$ALT{$chrom}{$position}{$ref}}) {
          if (exists $subalt{$chrom}{$position}{$ref}){
            unless ($subalt{$chrom}{$position}{$ref} =~ $ALT{$chrom}{$position}{$ref}{$library}){
              $subalt{$chrom}{$position}{$ref} = $subalt{$chrom}{$position}{$ref}.",".$ALT{$chrom}{$position}{$ref}{$library};
            }
          }
          else {
            $subalt{$chrom}{$position}{$ref}= $ALT{$chrom}{$position}{$ref}{$library};
          }
        }
      }
    }
  }
  
  #sub sort REF & ALT alleles
  foreach my $chrom (natsort keys %subref) {
    foreach my $position (sort {$a<=> $b} keys %{$subref{$chrom}}) {
      foreach my $ref (sort {$a cmp $b} keys %{$subref{$chrom}{$position}}) {
        my (%refhash, %althash,$refkey,$altkey);
        my @refarray = split(",", $subref{$chrom}{$position}{$ref});
        foreach (sort {$a cmp $b} @refarray) {$refhash{$_} = $_;}
        foreach (sort {$a cmp $b} keys %refhash){ $refkey .= $_.","; } 
        $NEWREF{$chrom}{$position}{$ref} = substr ($refkey, 0, -1);
        
        my @altarray = split(",", $subalt{$chrom}{$position}{$ref});
        foreach (sort {$a cmp $b} @altarray) {$althash{$_} = $_;}
        foreach (sort {$a cmp $b} keys %althash){ $altkey .= $_.","; }
        $NEWALT{$chrom}{$position}{$ref} = substr ($altkey, 0,-1);
      }
    }
  }
  
  #SORT CONSEQUENCE
  foreach my $chrom (natsort keys %CSQ) {
    foreach my $position (sort {$a<=> $b} keys %{$CSQ{$chrom}}) {
      foreach my $ref (sort {$a cmp $b} keys %{$CSQ{$chrom}{$position}}) {
        foreach my $library (sort {$a cmp $b || $a <=> $b} keys %{$CSQ{$chrom}{$position}{$ref}}) {
          if (exists $NEWCSQ{$chrom}{$position}{$ref}){
            unless ($NEWCSQ{$chrom}{$position}{$ref} =~ $CSQ{$chrom}{$position}{$ref}{$library}){
              die "Consequence should be the same:  $chrom $position not $NEWCSQ{$chrom}{$position}{$ref} equals $CSQ{$chrom}{$position}{$ref}{$library}\n";
            }
          }  
          else {
            $NEWCSQ{$chrom}{$position}{$ref} = $CSQ{$chrom}{$position}{$ref}{$library};
          }
        }
      }
    }
  }
  
  #SORT QUALITY
  foreach my $chrom (natsort keys %QUAL) {
    foreach my $position (sort {$a<=> $b} keys %{$QUAL{$chrom}}) {
      foreach my $ref (sort {$a cmp $b} keys %{$QUAL{$chrom}{$position}}) {
        my @quality = undef;
        foreach my $library (sort {$a cmp $b || $a <=> $b} keys %{$QUAL{$chrom}{$position}{$ref}}) {
          push @quality, $QUAL{$chrom}{$position}{$ref}{$library};
        }
        no warnings 'uninitialized';
                @quality = sort {$a <=> $b} @quality;
        $NEWQUAL{$chrom}{$position}{$ref} = $quality[$#quality];
      }
    }
  }
  
  #SORT DBSNP
  foreach my $chrom (natsort keys %DBSNP) {
    foreach my $position (sort {$a<=> $b} keys %{$DBSNP{$chrom}}) {
      foreach my $ref (sort {$a cmp $b} keys %{$DBSNP{$chrom}{$position}}) {
        foreach my $library (sort {$a cmp $b || $a <=> $b} keys %{$DBSNP{$chrom}{$position}{$ref}}) {
          if (exists $NEWDBSNP{$chrom}{$position}{$ref}){
            unless ($NEWDBSNP{$chrom}{$position}{$ref} =~ $DBSNP{$chrom}{$position}{$ref}{$library}){
              $NEWDBSNP{$chrom}{$position}{$ref} = '.';
            }
          }  
          else {
            $NEWDBSNP{$chrom}{$position}{$ref} = $DBSNP{$chrom}{$position}{$ref}{$library};
          }
        }
      }
    }
  }
  
  #SORT GENOTYPE
  foreach my $chrom (natsort keys %GT) {
    foreach my $position (sort {$a<=> $b} keys %{$GT{$chrom}}) {
      foreach my $ref (sort {$a cmp $b} keys %{$GT{$chrom}{$position}}) {
        foreach my $library (sort {$a cmp $b || $a <=> $b} keys %{$GT{$chrom}{$position}{$ref}}) {
          if (exists $NEWGT{$chrom}{$position}{$ref}){
            unless ($NEWGT{$chrom}{$position}{$ref} =~ $GT{$chrom}{$position}{$ref}{$library}){
              $subgt{$chrom}{$position}{$ref}{$GT{$chrom}{$position}{$ref}{$library}}++;
              #die "Genotype should be the same:  $chrom $position not $NEWGT{$chrom}{$position}{$ref} equals $GT{$chrom}{$position}{$ref}{$library}\n";
            }
          }  
          else {
            $subgt{$chrom}{$position}{$ref}{$GT{$chrom}{$position}{$ref}{$library}} = 1;
            $NEWGT{$chrom}{$position}{$ref} = $GT{$chrom}{$position}{$ref}{$library};
          }
        }
      }
    }
  }
    
  #order genotype
  my %odagt;
  foreach my $chrom (natsort keys %subgt) {
    foreach my $position (sort {$a<=> $b} keys %{$subgt{$chrom}}) {
      foreach my $ref (sort {$a cmp $b} keys %{$subgt{$chrom}{$position}}) {
        if ( (exists $subgt{$chrom}{$position}{$ref}{'0/1'}) && (exists $subgt{$chrom}{$position}{$ref}{'1/2'}) ){
          print "yes\t", $chrom,"\t",$position,"\t";
          if ( $subgt{$chrom}{$position}{$ref}{'0/1'} > $subgt{$chrom}{$position}{$ref}{'1/2'} ) {
            print $subgt{$chrom}{$position}{$ref}{'0/1'},"\t0%1\t";
            $subgt{$chrom}{$position}{$ref}{'0/1'} =  $subgt{$chrom}{$position}{$ref}{'0/1'} + $subgt{$chrom}{$position}{$ref}{'1/2'};
            print $subgt{$chrom}{$position}{$ref}{'0/1'},"\n";
          }
          elsif ( $subgt{$chrom}{$position}{$ref}{'0/1'} < $subgt{$chrom}{$position}{$ref}{'1/2'} ) {
            print $subgt{$chrom}{$position}{$ref}{'1/2'},"\t1%2\t";
            $subgt{$chrom}{$position}{$ref}{'1/2'} =  $subgt{$chrom}{$position}{$ref}{'0/1'} + $subgt{$chrom}{$position}{$ref}{'1/2'};
            print $subgt{$chrom}{$position}{$ref}{'1/2'},"\n";
          }
          elsif ( $subgt{$chrom}{$position}{$ref}{'0/1'} == $subgt{$chrom}{$position}{$ref}{'1/2'} ) {
            print $subgt{$chrom}{$position}{$ref}{'0/1'},"\t0%1=\t";
            $subgt{$chrom}{$position}{$ref}{'0/1'} =  $subgt{$chrom}{$position}{$ref}{'0/1'} + $subgt{$chrom}{$position}{$ref}{'1/2'};
            print $subgt{$chrom}{$position}{$ref}{'0/1'},"\n";
                #$subgt{$chrom}{$position}{$ref}{'0/1'} =  $subgt{$chrom}{$position}{$ref}{'0/1'} + $subgt{$chrom}{$position}{$ref}{'1/2'};
          }
          else{die "something is wrong";}
        }
        foreach my $geno (sort {$a cmp $b} keys %{$subgt{$chrom}{$position}{$ref}}){
          $odagt{$chrom}{$position}{$ref}{$subgt{$chrom}{$position}{$ref}{$geno}} = $geno;
        }
      }
    }
  }
  foreach my $chrom (natsort keys %odagt) {
    foreach my $position (sort {$a <=> $b} keys %{$odagt{$chrom}}) {
      foreach my $ref (sort {$a cmp $b} keys %{$odagt{$chrom}{$position}}) {
        my $newpost = (sort {$a <=> $b} keys %{$odagt{$chrom}{$position}{$ref}})[0];
        $NEWGT{$chrom}{$position}{$ref} = $odagt{$chrom}{$position}{$ref}{$newpost};
      }
    }
  }
}

sub MTD {
  #get metadata information
  foreach my $chrom (natsort keys %QUAL) {
    foreach my $position (sort {$a<=> $b} keys %{$QUAL{$chrom}}) {
      foreach my $ref (sort {$a cmp $b} keys %{$QUAL{$chrom}{$position}}) {
        foreach my $library (sort {$a cmp $b || $a <=> $b} keys %{$QUAL{$chrom}{$position}{$ref}}) {
          if (exists $MTD{$chrom}{$position}{$ref}) {
            $MTD{$chrom}{$position}{$ref} = $MTD{$chrom}{$position}{$ref}.",$library|$TISSUE{$library}|$QUAL{$chrom}{$position}{$ref}{$library}|$GT{$chrom}{$position}{$ref}{$library}";
          }
          else {
            $MTD{$chrom}{$position}{$ref} = "$library|$TISSUE{$library}|$QUAL{$chrom}{$position}{$ref}{$library}|$GT{$chrom}{$position}{$ref}{$library}";
          }
        }
      }
    }
  }
}

#--------------------------------------------------------------------------------

=head1 SYNOPSIS

 tad-export.pl [arguments] [-o <-vcf> output-filename]

 Optional arguments:
        -h, --help                      print help message
        -m, --man                       print complete documentation
        -v, --verbose                   use verbose output

    Arguments to retrieve database information
            --query                     perform sql queries directly to the mysql database
            --db2data                   perform configured modules 

        Arguments for db2data
            --nosql                    Query FastBit datafiles (specify [gene-information | gene_count-information | variant-information])

        Arguments for db2data
            --avgexp                    average expression (fpkm/tpm) values of specified genes
            --genexp                    expression (fpkm/tpm) values of genes across selected samples
            --chrvar                    chromosomal vriant distribution across selected samples
            --varanno                   variants with annotation information in genes or chromosomal region. 
 
        More Arguments for db2data
            --species                   Organism Name (required)
            --gene                      Gene Name(s)
            --tissue                    Tissue Name(s) [ multiple tissues should be separated by comma ]
            -sample, --samples          Sample ID(s) [ multiple sample(s) should be separated by comma ]
            --chromosome                Chromosome(s) [ multiple chromosome(s) should be separated by comma ]
            --region                    Chromosomal region (e.g 1-1000000 or 1000000)
            
    Arguments to export
            -o, --output                output results in file name specified
            --vcf                       output 'varanno' results in vcf format 

 Function: export data from the database

 Example: #execute "show tables" using -query
      tad-export.pl -query 'show tables'
      tad-export.pl -query 'show tables' -o tables.txt
                    
      #execute "select * from VarSummary" using -query
      tad-export.pl -query 'select * from VarSummary'
      tad-export.pl -query 'select * from VarSummary' -o output.txt
                    
      #execute query on nosql, to view the first ten rows in the gene-information folder
      tad-export.pl --nosql gene-information --query 'select genename,organism,tissue,fpkm,tpm where 1=1 limit 10'



      #all variants for organism Gallus Gallus
      tad-export.pl --db2data --varanno --species 'Gallus gallus'
      tad-export.pl --db2data --varanno --species 'Gallus gallus' -o output.txt
      tad-export.pl --db2data --varanno --species 'Gallus gallus' -o -vcf output.vcf
                    
      #variants and annotation information of genes 'OPTN' and 'GDF' in Gallus gallus organism
      tad-export.pl --db2data --varanno --species 'Gallus gallus' --gene 'OPTN,GDF'
                    
      #variants and annotation information of chromosomes 'chr1,chr2' in Gallus gallus organism
      tad-export.pl --db2data --varanno --species 'Gallus gallus' --chromosome 'chr1,chr2'
      tad-export.pl --db2data --varanno --species 'Gallus gallus' --chromosome 'chr1,chr2' -o output.txt
      tad-export.pl --db2data --varanno --species 'Gallus gallus' --chromosome 'chr1,chr2' -o -vcf vcfoutput.vcf
        
      #variants and annotation information of chromosomal region 'chr1:50000-900000' in Gallus gallus organism
      tad-export.pl --db2data --varanno --species 'Gallus gallus' --chromosome 'chr1' -region 50000-900000
                    
      #average fpkm or tpm values for genes 'OPTN' and 'GDF' in all tissues of Gallus gallus organism
      tad-export.pl --db2data --avgexp --fpkm --species 'Gallus gallus' --gene 'OPTN,GDF'
      tad-export.pl --db2data --avgexp --tpm --species 'Gallus gallus' --gene 'OPTN,GDF'
                    
      #average fpkm and tpm values for genes 'OPTN' and 'GDF' in the pituitary gland of Gallus gallus organism
      tad-export.pl --db2data --avgexp --species 'Gallus gallus' --gene 'OPTN,GDF' --tissue 'pituitary gland'
      
      #fpkm or tpm values for genes 'OPTN' and 'GDF' in all tissues of Gallus gallus organism
      tad-export.pl --db2data --genexp --fpkm --species 'Gallus gallus' --gene 'OPTN,GDF'
      tad-export.pl --db2data --genexp --tpm --species 'Gallus gallus' --gene 'OPTN,GDF'
                    


 Version: $ Date: 2016-12-05 15:50:08 (Mon, 05 Dec 2016) $

=head1 OPTIONS

=over 8

=item B<--help>

print a brief usage message and detailed explantion of options.

=item B<--man>

print the complete manual of the program.

=item B<--verbose>

use verbose output.
                        
=item B<--query>

perform sql queries directly to the mysql database.

=item B<--db2data>

perform pre-configured query modules.

=item B<--avgexp>

view average, maximum and minumum expression fpkm and tpm values of genes specified.

=item B<--genexp>

view gene expression fpkm and tpm values of genes across selected samples.

=item B<--chrvar>

provides summary counts of the different variant types per chromosome for each sample.

=item B<--varanno>

provides variants with respective annotation information based on genes or chromosomes.

=item B<--species>

species or organism name.(required)

=item B<--gene>

gene name, multiple gene names can be specified (separated by commas).

=item B<--tissue>

tissue name, multiple tissues can be specified (separated by commas).

=item B<--sample>

sample id name, multiple samples can be specified (separated by commas).

=item B<--chromosome>

chromosome name, multiple chromosomes can be specified (separated by commas).

=item B<--region>

chromosomal location. Chromosomal location can either be a position and a
3000bp region around that position will be provided, or a region range.
(e.g specifying 1000000 will provide results from 985000-1015000 or
specifying '985000-1015000' will provide results from the specified region)

=item B<--output>

output results in tab-delimited format to filename provided.
Suffix of filename is changed to .txt where applicable.

=item B<--vcf>

output file will be in variant call format. Suffix of filename is
changed to .vcf where applicable. The vcf file can be visualized using UCSC genome browser. 

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
