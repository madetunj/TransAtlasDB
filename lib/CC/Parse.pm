#package CC::Parse;
use strict;
use Cwd qw(abs_path);
use lib dirname(abs_path $0) .'/lib';
use Spreadsheet::Read;
use Text::TabularDisplay;
use Term::ANSIColor;
use List::MoreUtils qw(uniq);
use Sort::Key::Natural qw(natsort);


my ($sth, $dbh, $ibis, $t);
my ($precount, $count, $verdict);

sub excelcontent { #read excel content
	unless($_[0] =~ /\.xls/){pod2usage("Error: File \"$_[0]\" is not an excel file.");}
  my $workbook = ReadData($_[0]) or pod2usage("Error: Could not open excel file \"$_[0]\"");
  my ($odacontent, $source_cell);
  foreach my $source_sheet_number (1..length($workbook)) {
    my @rows = Spreadsheet::Read::rows($workbook->[$source_sheet_number]);
    my @column = Spreadsheet::Read::row($workbook->[$source_sheet_number],1);
    unless ($#rows < 0) {
      $odacontent .= "%%$workbook->[$source_sheet_number]{label}\n";
      foreach my $row_index (1..$#rows+1) {
        foreach my $col_index (1..$#column+1) {
          $source_cell = $workbook->[$source_sheet_number]{cell}[$col_index][$row_index];
          $odacontent .= $source_cell. "?abc?";
        }
        $odacontent .= "\n";
      }
    }
  }
  my @content = split('%%', $odacontent);
	@content = @content[2..$#content]; 
  return @content;
}

sub tabcontent { #read tadcontent
  open (BOOK,"<",$_[0]) or pod2usage ("Error: Could not open source file \"$_[0]\"");
  my @content = <BOOK>; close (BOOK); chomp @content;
  our (%INDEX, %columnpos);
  my @header = split("\t", $content[0]);

	foreach my $no (0..$#header){
			$header[$no] =~ s/\s+$//;
      $columnpos{$no} = lc($header[$no]);
  }
  foreach (1..$#content) {
    my @value = split ("\t", $content[$_]);
    if (length $value[0] > 1){
      foreach my $na (0..$#value){
        $INDEX{$_}{$columnpos{$na}} = $value[$na];
      }
    }
  }
	
  return \%INDEX;
}

sub SUMMARY { #tad-interact option A
	open(LOG, ">>", $_[1]) or die "\nERROR:\t cannot write LOG information to log file $_[1] $!\n"; #open log file
	print colored("A.\tSUMMARY OF SAMPLES IN THE DATABASE.", 'bright_red on_black'),"\n";
	print LOG "A.\tSUMMARY OF SAMPLES IN THE DATABASE.\n";
	$dbh = $_[0];	
	#first: Total number of animals (organism, count)
		$t = Text::TabularDisplay->new(qw(Organism Count));
		$sth = $dbh->prepare("select organism, count(*) from Animal group by organism");
		$sth->execute or die "SQL Error: $DBI::errstr\n";
		while (my @row = $sth->fetchrow_array() ) {
			$t->add(@row);
		}
		$sth = $dbh->prepare("select count(*) from Animal"); #FINAL ROW
		$sth->execute or die "SQL Error: $DBI::errstr\n";
		while (my @row = $sth->fetchrow_array() ) {
			$t->add("Total", @row);
		}
		print colored("Summary of Organisms.", 'bold red'), "\n";
		print color('red');print $t-> render, "\n\n";print color('reset');
		print LOG "Summary of Organisms.\n";
		print LOG $t-> render, "\n\n";
	
	#second: Total number of samples (organism, tissue, count)
		$t = Text::TabularDisplay->new(qw(Organism Tissue Count));
		$sth = $dbh->prepare("select organism , tissue, count(*) from Animal a join Sample b on a.animalid = b.derivedfrom group by organism, tissue");
		$sth->execute or die "SQL Error: $DBI::errstr\n";
		while (my @row = $sth->fetchrow_array() ) {
			$t->add(@row);
		}
		print colored("Summary of Samples.", 'bold green'), "\n";
		print color('green');print $t-> render, "\n\n";print color('reset');
		print LOG "Summary of Samples.\n";
		print LOG $t-> render,"\n\n";
	
	#third: Summary of libraries processed (organism, sample, processed samples)
		$sth = $dbh->prepare("select a.organism, format(count(b.sampleid),0), format(count(c.sampleid),0), format(count(d.sampleid),0), format(count(e.sampleid),0) from Animal a join Sample b on a.animalid = b.derivedfrom left outer join vw_sampleinfo c on b.sampleid = c.sampleid left outer join GeneStats d on c.sampleid = d.sampleid left outer join VarSummary e on c.sampleid = e.sampleid group by a.organism");
		$sth->execute or die "SQL Error: $DBI::errstr\n";
		$t = Text::TabularDisplay->new(qw(ORGANISM RECORDED PROCESSED GENES VARIANTS));
		while (my @row = $sth->fetchrow_array() ) {
			$t->add(@row);
		}
		$sth = $dbh->prepare("select format(count(b.sampleid),0), format(count(c.sampleid),0), format(count(d.sampleid),0), format(count(e.sampleid),0) from Animal a join Sample b on a.animalid = b.derivedfrom left outer join vw_sampleinfo c on b.sampleid = c.sampleid left outer join GeneStats d on c.sampleid = d.sampleid left outer join VarSummary e on c.sampleid = e.sampleid"); #FINAL ROW
		$sth->execute or die "SQL Error: $DBI::errstr\n";
		while (my @row = $sth->fetchrow_array() ) {
			$t->add("Total", @row);
		}
		print colored("Summary of Samples processed.", 'bold magenta'), "\n";
		print color('magenta');print $t-> render, "\n\n";print color('reset');
		print LOG "Summary of Samples processed.\n";
		print LOG $t-> render, "\n\n";
		
	##fourth: Summary of database content
		$sth = $dbh->prepare("select organism Species, format(sum(genes),0) Genes, format(sum(totalvariants),0) Variants from vw_sampleinfo group by species");
		$sth->execute or die "SQL Error: $DBI::errstr\n";
		$t = Text::TabularDisplay->new(qw(ORGANISM GENES(total) VARIANTS(total)));
		while (my @row = $sth->fetchrow_array() ) {
			$t->add(@row);
		}
		$sth = $dbh->prepare("select format(sum(genes),0) Genes, format(sum(totalvariants ),0) Variants from vw_sampleinfo"); #FINAL ROW
		$sth->execute or die "SQL Error: $DBI::errstr\n";
		while (my @row = $sth->fetchrow_array() ) {
			$t->add("Total", @row);
		}
		print colored("Summary of Database Content.", 'bold blue'), "\n";
		print color('blue'); print $t-> render, "\n\n"; print color('reset');
		print LOG "Summary of Database Content.\n";
		print LOG $t-> render, "\n\n";
}

sub METADATA { #tad-interact option B
	open(LOG, ">>", $_[1]) or die "\nERROR:\t cannot write LOG information to log file $_[1] $!\n"; #open log file
	print colored("B.\tMETADATA OF SAMPLES.", 'bright_red on_black'),"\n";
	print LOG "B.\tMETADATA OF SAMPLES.\n";
	$dbh = $_[0]; 
	$t = Text::TabularDisplay->new(qw(SampleID	AnimalID Organism Tissue Scientist Organization AnimalDescription SampleDescription DateImported)); #header
	$precount = 0; $precount = $dbh->selectrow_array("select count(*) from vw_metadata"); #count all info in metadata
	my $indent = "";
	unless ($precount > 9) { #preset the output to be less than 10 row
		$sth = $dbh->prepare("select * from vw_metadata order by date");
	} else {
		$precount= 10; $indent = "Only";
		$sth = $dbh->prepare("select * from vw_metadata order by date desc limit $precount");
	}
	$sth->execute or die "SQL Error: $DBI::errstr\n";
	while (my @row = $sth->fetchrow_array() ) {
		$t->add(@row);
	}
	$count = 0; $count = $dbh->selectrow_array("select count(*) from Sample");
	
	if ($count > 0 ) {
		print colored("$precount out of $count results displayed.", 'underline'), "\n";
		print LOG "$precount out of $count results displayed.\n";
		printerr $t-> render, "\n\n"; #print results

		print color('bright_black'); #additional procedure
		print "---------------------------ADDITIONAL PROCEDURE---------------------------\n";
		print "--------------------------------------------------------------------------\n";
		print "NOTICE:\t $indent $precount samples are displayed.\n";
		print "PLEASE RUN EITHER THE FOLLOWING COMMANDS TO VIEW OR EXPORT THE COMPLETE RESULT.\n";
		print "\ttad-export.pl --query 'select * from vw_metadata'\n";
		print "\ttad-export.pl --query 'select * from vw_metadata' --output output.txt\n";
		print "--------------------------------------------------------------------------\n";
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print LOG "---------------------------ADDITIONAL PROCEDURE---------------------------\n";
		print LOG "--------------------------------------------------------------------------\n";
		print LOG "NOTICE:\t $indent $precount samples are displayed.\n";
		print LOG "PLEASE RUN EITHER THE FOLLOWING COMMANDS TO VIEW OR EXPORT THE COMPLETE RESULT.\n";
		print LOG "\ttad-export.pl --query 'select * from vw_metadata'\n";
		print LOG "\ttad-export.pl --query 'select * from vw_metadata' --output output.txt\n";
		print LOG "--------------------------------------------------------------------------\n";
		print LOG "--------------------------------------------------------------------------\n";
		printerr "\n\n";
	} else {
		printerr "ERROR:\tEmpty dataset, import Sample Information using tad-import.pl -metadata\n"; next MAINMENU;
	} 
}

sub TRANSCRIPT { #tad-interact option C
	open(LOG, ">>", $_[1]) or die "\nERROR:\t cannot write LOG information to log file $_[1] $!\n"; #open log file
	print colored("C.\tTRANSCRIPTOME ANALYSIS SUMMARY OF SAMPLES.", 'bright_red on_black'),"\n";
	print LOG "C.\tTRANSCRIPTOME ANALYSIS SUMMARY OF SAMPLES.\n";
	$dbh = $_[0]; 
	$t = Text::TabularDisplay->new(qw(SampleID	Organism Tissue TotalReads MappedReads	AlignmentRate(%) Genes(total) Variants(total) SNVs(total) InDELs(total))); #header
	$precount = 0; $precount = $dbh->selectrow_array("select count(*) from vw_sampleinfo"); #count all info in processed samples
	my $indent = "";
	$count = $precount;
	unless ($precount > 9) { #preset the output to be less than 10 rows
		$sth = $dbh->prepare("select * from vw_sampleinfo");
	} else {
		$precount= 10; $indent = "Only";
		$sth = $dbh->prepare("select * from vw_sampleinfo limit $precount");
	}
	$sth->execute or die "SQL Error: $DBI::errstr\n";
	while (my @row = $sth->fetchrow_array() ) {
		foreach (@row){unless($_){$_ = 0;}}
		$t->add(@row);
	}
	if ($count > 0 ) {
		print colored("$precount out of $count results displayed.", 'underline'), "\n";
		print LOG "$precount out of $count results displayed.\n";
		printerr $t-> render, "\n\n"; #print results
		
		print color('bright_black'); #additional procedure
		print "---------------------------ADDITIONAL PROCEDURE---------------------------\n";
		print "--------------------------------------------------------------------------\n";
		print "NOTICE:\t $indent $precount samples are displayed.\n";
		print "PLEASE RUN EITHER THE FOLLOWING COMMANDS TO VIEW OR EXPORT THE COMPLETE RESULT.\n";
		print "\ttad-export.pl --query 'select * from vw_sampleinfo'\n";
		print "\ttad-export.pl --query 'select * from vw_sampleinfo' --output output.txt\n";
		print "--------------------------------------------------------------------------\n";
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print LOG "---------------------------ADDITIONAL PROCEDURE---------------------------\n";
		print LOG "--------------------------------------------------------------------------\n";
		print LOG "NOTICE:\t $indent $precount samples are displayed.\n";
		print LOG "PLEASE RUN EITHER THE FOLLOWING COMMANDS TO VIEW OR EXPORT THE COMPLETE RESULT.\n";
		print LOG "\ttad-export.pl --query 'select * from vw_sampleinfo'\n";
		print LOG "\ttad-export.pl --query 'select * from vw_sampleinfo' --output output.txt\n";
		print LOG "--------------------------------------------------------------------------\n";
		print LOG "--------------------------------------------------------------------------\n";
		printerr "\n\n";
	} else {
		printerr "ERROR:\tEmpty dataset, import Sample Information using tad-import.pl -metadata\n"; next MAINMENU;
	} 
}

sub AVERAGE { #tad-interact option D
	open(LOG, ">>", $_[1]) or die "\nERROR:\t cannot write LOG information to log file $_[1] $!\n"; #open log file
	print colored("D.\tAVERAGE FPKM VALUES OF INDIVIDUAL GENES.", 'bright_red on_black'),"\n";
	print LOG "D.\tAVERAGE FPKM VALUES OF INDIVIDUAL GENES.\n";
	my $gfastbit = $_[2]."/gene-information";
	$dbh = $_[0]; $ibis = $_[4];
	my (%TISSUE, %GENES, %AVGFPKM, $tissue, $genes , $species, %ORGANISM);
	$count = 0;
	$sth = $dbh->prepare("select distinct organism from vw_sampleinfo where genes is not null"); #get organism(s)
	$sth->execute or die "SQL Error: $DBI::errstr\n";
	my $number = 0;
	while (my $row = $sth->fetchrow_array() ) {
		$number++;
		$ORGANISM{$number} = $row;
	}
	if ($number > 1) { #if there are more than one processed organism
		print color ('bold');
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print "\nThe following organisms are available; select an organism : \n";
		foreach (sort {$a <=> $b} keys %ORGANISM) { print "  ", $_,"\.  $ORGANISM{$_}\n";}
		print color('bold');
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print "\n ? : ";
		chomp ($verdict = int(<>)); print "\n";
	} else { $verdict = 1; } #else if there's only one organism 
	if ($verdict >= 1 && $verdict <= $number ) {
		$species = $ORGANISM{$verdict};
		printerr "\nORGANISM : $species\n";
		print "\nSelect genes (multiple genes can be separated by comma) ? "; #ask for genes
	  chomp ($verdict = uc(<>)); 
		$verdict =~ s/\s+//g;
		unless ($verdict) { printerr "ERROR:\t Gene(s) not provided\n"; next MAINMENU; } # if genes aren't provided
		my @genes = split(",", $verdict); 
		$sth = $dbh->prepare("select distinct tissue from vw_sampleinfo where genes is not null and organism = '$species'"); #get tissues
		$sth->execute or die "SQL Error: $DBI::errstr\n";
		my $tnumber = 0;
		while (my $row = $sth->fetchrow_array() ) {
			$tnumber++;
			$TISSUE{$tnumber} = $row;
			$tissue .= $row.",";
		} chop $tissue;
		$verdict = undef;
		if ($tnumber > 1) {
			print color ('bold');
			print "--------------------------------------------------------------------------\n";
			print color('reset');
			foreach (sort {$a <=> $b} keys %TISSUE) { print "  ", $_," :  $TISSUE{$_}\n";}
			print color('bold');
			print "--------------------------------------------------------------------------\n";
			print color('reset');
			print "\nSelect tissue (multiple tissues can be separated by comma or 0 for all) ? "; #ask for tissues
			chomp ($verdict = <>); print "\n";
		} else { $verdict = 0;}
		$TISSUE{0} = $tissue;
		$verdict =~ s/\s+//g;
		unless ($verdict) { $verdict = 0; }
		my @tissue = split(",", $verdict); undef $tissue; 
		foreach (@tissue) {
			unless (exists $TISSUE{$_}){
				printerr "ERROR\t: Tissue number $_ not valid\n"; next MAINMENU; #if tissue isn't provided
			} else {
				$tissue .= $TISSUE{$_}.",";
			}
		} chop $tissue;
		printerr "\nTISSUE(S) selected: $tissue\n";
		@tissue = split("\,",$tissue);
		foreach my $gene (@genes){
			foreach my $ftissue (@tissue) {
				#my $syntax = "call usp_gdtissue(\"".$gene."\",\"".$ftissue."\",\"". $species."\")";
				#$sth = $dbh->prepare($syntax);
				#$sth->execute() or die "SQL Error: $DBI::errstr\n";
				`$ibis -d $gfastbit -q 'select genename, max(fpkm), avg(fpkm), min(fpkm) where genename like "%$gene%" and tissue = "$ftissue" and organism = "$species"' -o $_[3] 2>>$_[1]`;
				my $found = `head -n 1 $_[3]`;
				if (length($found) > 1) {
					open(IN,"<",$_[3]);
					while (<IN>){
						chomp;
						my ($genename,$max,$avg,$min) = split (/\, /, $_, 4);
						$genename =~ s/^'|'$|^"|"$//g; #removing the quotation marks from the words
						if ($genename =~ /NULL/) { $genename = "-"; }
						$AVGFPKM{$genename}{$ftissue} = "$max|$avg|$min";
					}
					$genes .= $gene.",";
				} else {
					printerr "NOTICE:\t No Results found with gene '$gene'\n";
				} 
				`rm -rf $_[3]`;
		
				#my $found = $sth->fetch();
				#if ($found) {
				#	$sth->execute() or die "SQL Error: $DBI::errstr\n";
				#	while (my ($genename, $max, $avg, $min) = $sth->fetchrow_array() ) { 
				#		$AVGFPKM{$genename}{$ftissue} = "$max|$avg|$min";
				#	}
				#	$genes .= $gene;
				#} else {
				#	printerr "NOTICE:\t No Results found with gene '$gene'\n";
				#}
			}
		}
		$count = scalar keys %AVGFPKM;
	} elsif ($number == 0){
		printerr "\nERROR:\tEmpty dataset, import Gene Information using tad-import.pl -data2db\n"; next MAINMENU;
	} else {
		printerr "ERROR:\t Organism number was not valid \n"; next MAINMENU;
	}
  $t = Text::TabularDisplay->new(qw(GeneName Tissue MaximumFpkm AverageFpkm MinimumFpkm)); #header
	$precount = 0;
	foreach my $a (sort keys %AVGFPKM){ #preset to 10 rows
		unless ($precount >= 10) { 
			foreach my $b (sort keys % {$AVGFPKM{$a} }){
				unless ($precount >= 10) {
					my @all = split('\|', $AVGFPKM{$a}{$b}, 3);
					$precount++;
					$t->add($a, $b, $all[0], $all[1], $all[2]);
				}
			}
    }    
  }
	my $indent;
	if ($precount >= $count) {
		$indent = "";
	} else {
		$indent = "Only";
	}
	chop $genes;
	if ($count > 0 ) {
		print colored("$precount out of $count results displayed.", 'underline'), "\n";
		print LOG "$precount out of $count results displayed.\n";
		printerr $t-> render, "\n\n"; #print results
		
		print color('bright_black'); #additional procedure
		print "---------------------------ADDITIONAL PROCEDURE---------------------------\n";
		print "--------------------------------------------------------------------------\n";
		print "NOTICE:\t $indent $precount sample(s) displayed.\n";
		print "PLEASE RUN EITHER THE FOLLOWING COMMANDS TO VIEW OR EXPORT THE COMPLETE RESULT.\n";
		print "\ttad-export.pl --db2data --avgfpkm --species '$species' --gene '$genes' --tissue '$tissue'\n";
		print "\ttad-export.pl --db2data --avgfpkm --species '$species' --gene '$genes' --tissue '$tissue' --output output.txt\n";
		print "--------------------------------------------------------------------------\n";
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print LOG "---------------------------ADDITIONAL PROCEDURE---------------------------\n";
		print LOG "--------------------------------------------------------------------------\n";
		print LOG "NOTICE:\t $indent $precount sample(s) displayed.\n";
		print LOG "PLEASE RUN EITHER THE FOLLOWING COMMANDS TO VIEW OR EXPORT THE COMPLETE RESULT.\n";
		print LOG "\ttad-export.pl --db2data --avgfpkm --species '$species' --gene '$genes' --tissue '$tissue'\n";
		print LOG "\ttad-export.pl --db2data --avgfpkm --species '$species' --gene '$genes' --tissue '$tissue' --output output.txt\n";
		print LOG "--------------------------------------------------------------------------\n";
		print LOG "--------------------------------------------------------------------------\n";
		printerr "\n\n";
	} else {
		printerr "NOTICE:\t No Results based on search criteria: $genes\n";
	}
}

sub GENEXP { #tad-interact option E
	open(LOG, ">>", $_[1]) or die "\nERROR:\t cannot write LOG information to log file $_[1] $!\n"; # open log file
	print colored("E.\tGENE EXPRESSION ACROSS SAMPLES.", 'bright_red on_black'),"\n";
	print LOG "E.\tGENE EXPRESSION ACROSS SAMPLES.\n";
	my $gfastbit = $_[2]."/gene-information";
	$dbh = $_[0]; $ibis = $_[4];
	my (%FPKM, %POSITION, %ORGANISM, %SAMPLE, %REALPOST, %CHROM, $species, $sample, $finalsample, $genes, $syntax, @row, $indent);
	$count = 0;
	$sth = $dbh->prepare("select distinct organism from vw_sampleinfo where genes is not null"); #get organisms
	$sth->execute or die "SQL Error: $DBI::errstr\n";
	my $number = 0;
	while (my $row = $sth->fetchrow_array() ) {
		$number++;
		$ORGANISM{$number} = $row;
	}
	if ($number > 1) {
		print color ('bold');
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print "\nThe following organisms are available; select an organism : \n";
		foreach (sort {$a <=> $b} keys %ORGANISM) { print "  ", $_,"\.  $ORGANISM{$_}\n";}
		print color('bold');
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print "\n ? : ";
		chomp ($verdict = int(<>)); print "\n";
	} else { $verdict = 1; }
	if ($verdict >= 1 && $verdict <= $number ) {
		$species = $ORGANISM{$verdict};
		$sth = $dbh->prepare("select sampleid from vw_sampleinfo where organism = '$species' and genes is not null"); #get samples
		$sth->execute or die "SQL Error: $DBI::errstr\n";
		my $snumber= 0;
		while (my $row = $sth->fetchrow_array() ) {
			$snumber++;
			$SAMPLE{$snumber} = $row;
			$sample .= $row.",";
		} chop $sample;
		printerr "\nORGANISM : $species\n";
		$verdict = undef;
		if ($snumber > 1) {
			print color ('bold');
			print "--------------------------------------------------------------------------\n";
			print color('reset');
			foreach (sort {$a <=> $b} keys %SAMPLE) { print "  ", $_," :  $SAMPLE{$_}\n";}
			print color('bold');
			print "--------------------------------------------------------------------------\n";
			print color('reset');
			print "\nSelect sample (multiple samples can be separated by comma or 0 for all) ? ";
			chomp ($verdict = <>); print "\n";
		} else { $verdict = 0;}
		$SAMPLE{0} = $sample;
		$verdict =~ s/\s+//g;
		unless ($verdict) { $verdict = 0; }
		my @sample = split(",", $verdict); undef $sample;
		foreach (@sample) {
			unless (exists $SAMPLE{$_}){
				printerr "ERROR\t: Sample number $_ not valid\n"; next MAINMENU; #if sample is not provided
			} else {
				$sample .= $SAMPLE{$_}.",";
			}
		} chop $sample;
		if ($verdict =~ /^0/) {
			printerr "\nSAMPLE(S) selected: 'all samples for $species'\n";
		} else {
			printerr "\nSAMPLE(S) selected: $sample\n";
			$finalsample = $sample;
		}
		my @newsample;
		@sample = split("\,",$sample);
		if ($#sample > 1) {
			@newsample = @sample[0..1];
		} else { @newsample = @sample;}
		my @array = ("GENE", "CHROM", @newsample);
		$t = Text::TabularDisplay->new(@array);
		print "\nSelect genes (multiple genes can be separated by comma or 0 for all) ? "; #type in genes 
	  chomp ($verdict = uc(<>)); print "\n";
		$verdict =~ s/\s+//g;
		unless ($verdict) { $verdict = 0; }
		if ($verdict =~ /^0/) { 
			printerr "GENE(S) selected : 'all genes'\n";
			$syntax = "select genename, fpkm, sampleid, chrom, start, stop where sampleid in ("; #syntax
			foreach (@newsample) { $syntax .= "'$_',";} chop $syntax; $syntax .= ") order by geneid desc";
		}else {
			my @genes = split(",", $verdict);
			$genes = $verdict;
			printerr "GENE(S) selected : $verdict\n";
			$syntax = "select genename, fpkm, sampleid, chrom, start, stop where sampleid in (";
			foreach (@newsample) { $syntax .= "'$_',";} chop $syntax; $syntax .= ") and (";
			foreach (@genes) { $syntax .= " genename like '%$_%' or"; } $syntax = substr($syntax, 0, -2); $syntax .= ") order by geneid desc";
		}
		#$sth = $dbh->prepare($syntax);
		#$sth->execute or die "SQL Error:$DBI::errstr\n";
		`$ibis -d $gfastbit -q "$syntax" -o $_[3] 2>>$_[1]`;
		$count = 0;
		open(IN,"<",$_[3]);
		while (<IN>){
			chomp;
			my ($geneid, $fpkm, $library, $chrom, $start, $stop) = split /\, /;
			$geneid =~ s/^'|'$|^"|"$//g; $library =~ s/^'|'$|^"|"$//g; $chrom =~ s/^'|'$|^"|"$//g; #removing quotation marks if applicable
			$count++;
			$FPKM{"$geneid|$chrom"}{$library} = $fpkm;
			$CHROM{"$geneid|$chrom"} = $chrom;
			$POSITION{"$geneid|$chrom"}{$library} = "$start|$stop";
		}
		close (IN); `rm -rf $_[3]`;
		
		foreach my $genest (sort keys %POSITION) {
			if ($genest =~ /^[0-9a-zA-Z]/){
				my $status = "nothing";
				my (@newstartarray,@newstoparray,$realstart, $realstop);
				foreach my $libest (sort keys % {$POSITION{$genest}} ){
					my @newposition = split('\|',$POSITION{$genest}{$libest},2);  
					my $status = "nothing";
				
					if ($newposition[0] > $newposition[1]) {
						$status = "reverse";
					}
					elsif ($newposition[0] < $newposition[1]) {
						$status = "forward";
					}
					push @newstartarray, $newposition[0];
					push @newstoparray, $newposition[1];
					
					if ($status =~ /forward/){
						$realstart = (sort {$a <=> $b} @newstartarray)[0];
						$realstop = (sort {$b <=> $a} @newstoparray)[0];
					}
					elsif ($status =~ /reverse/){
						$realstart = (sort {$b <=> $a} @newstartarray)[0];
						$realstop = (sort {$a <=> $b} @newstoparray)[0];
					}
					else { die "ERROR:\t Chromsomal position for $genest in sample $libest is unusual\n"; }
				}
				$REALPOST{$genest} = "$realstart|$realstop";
			}
		}
		$precount = 0;
		$indent = '';
		foreach my $genename (sort keys %FPKM){  
			if ($genename =~ /^[0-9a-zA-Z]/){
				if ($precount < 10) {
					my ($newrealstart,$newrealstop) = split('\|',$REALPOST{$genename},2);
					@row = ();
					my $realgenes = (split('\|',$genename))[0];
					push @row, ($realgenes, $CHROM{$genename}."\:".$newrealstart."\-".$newrealstop);
					foreach (0..$#newsample) { 
						if (exists $FPKM{$genename}{$newsample[$_]}){
							push @row, $FPKM{$genename}{$newsample[$_]};
						}
						else {
							push @row, "0";
						}
					} 
				} else { $indent = "Only"; next;} #adding the ten count conditionality
				$precount++;
				$t->add(@row);
			} 
		}
	} elsif ($number == 0){
		printerr "\nERROR:\tEmpty dataset, import Gene Information using tad-import.pl -data2db\n"; next MAINMENU;
	} else {
		printerr "ERROR:\t Organism number was not valid \n"; next MAINMENU;
	}

	print colored("$precount out of $count results displayed.", 'underline'), "\n";
	print LOG "$precount out of $count results displayed.\n";
	printerr $t-> render, "\n\n"; #print results
	
	my ($dgenes, $dsamples);
	if ($genes) {$dgenes = "--gene '$genes'";}
	if ($finalsample) {$dsamples = " --samples '$sample'";}
	print color('bright_black'); #additional procedure
	print "---------------------------ADDITIONAL PROCEDURE---------------------------\n";
	print "--------------------------------------------------------------------------\n";
	print "NOTICE:\t $indent $precount sample(s) displayed.\n";
	print "PLEASE RUN EITHER THE FOLLOWING COMMANDS TO VIEW OR EXPORT THE COMPLETE RESULT.\n";
	print "\ttad-export.pl --db2data --genexp --species '$species' $dgenes$dsamples\n";
	print "\ttad-export.pl --db2data --genexp --species '$species' $dgenes$dsamples --output output.txt\n";
	print "--------------------------------------------------------------------------\n";
	print "--------------------------------------------------------------------------\n";
	print color('reset');
	print LOG "---------------------------ADDITIONAL PROCEDURE---------------------------\n";
	print LOG "--------------------------------------------------------------------------\n";
	print LOG "NOTICE:\t $indent $precount sample(s) displayed.\n";
	print LOG "PLEASE RUN EITHER THE FOLLOWING COMMANDS TO VIEW OR EXPORT THE COMPLETE RESULT.\n";
	print LOG "\ttad-export.pl --db2data --genexp --species '$species' $dgenes$dsamples\n";
	print LOG "\ttad-export.pl --db2data --genexp --species '$species' $dgenes$dsamples --output output.txt\n";
	print LOG "--------------------------------------------------------------------------\n";
	print LOG "--------------------------------------------------------------------------\n";
	printerr "\n\n";
}

sub CHRVAR { #tad-interact option F
	open(LOG, ">>", $_[1]) or die "\nERROR:\t cannot write LOG information to log file $_[1] $!\n"; #open log file
	print colored("F.\tVARIANT CHROMOSOMAL DISTRIBUTION ACROSS SAMPLES.", 'bright_red on_black'),"\n";
	print LOG "F.\tVARIANT CHROMOSOMAL DISTRIBUTION ACROSS SAMPLES.\n";
	$dbh = $_[0];
	my (%VARIANTS, %SNPS, %INDELS, %ORGANISM, %SAMPLE, %CHROM, $species, $chromsyntax, $sample, $chromosome, $syntax, @row, @newsample, @sample, $indent);
	
	$count = 0;
	$sth = $dbh->prepare("select distinct organism from vw_sampleinfo where totalvariants is not null"); #get organism
	$sth->execute or die "SQL Error: $DBI::errstr\n";
	my $number = 0;
	while (my $row = $sth->fetchrow_array() ) {
		$number++;
		$ORGANISM{$number} = $row;
	}
	if ($number > 1) {
		print color ('bold');
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print "\nThe following organisms are available; select an organism : \n";
		foreach (sort {$a <=> $b} keys %ORGANISM) { print "  ", $_,"\.  $ORGANISM{$_}\n";}
		print color('bold');
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print "\n ? : ";
		chomp ($verdict = int(<>)); print "\n";
	} else { $verdict = 1; }
	if ($verdict >= 1 && $verdict <= $number ) {
		$species = $ORGANISM{$verdict};
		$sth = $dbh->prepare("select distinct sampleid from vw_sampleinfo where organism = '$species' and totalvariants is not null"); #get sampleids
		$sth->execute or die "SQL Error: $DBI::errstr\n";
		my $snumber= 0;
		while (my $row = $sth->fetchrow_array() ) {
			$snumber++;
			$SAMPLE{$snumber} = $row;
			$sample .= $row.",";
		} chop $sample;
		printerr "\nORGANISM : $species\n";
		$verdict = undef;
		if ($snumber > 1) {
			print color ('bold');
			print "--------------------------------------------------------------------------\n";
			print color('reset');
			foreach (sort {$a <=> $b} keys %SAMPLE) { print "  ", $_," :  $SAMPLE{$_}\n";}
			print color('bold');
			print "--------------------------------------------------------------------------\n";
			print color('reset');
			print "\nSelect sample (multiple samples can be separated by comma or 0 for all) ? ";
			chomp ($verdict = <>); print "\n";
		} else { $verdict = 0;}
		$SAMPLE{0} = $sample;
		undef $sample;
		$verdict =~ s/\s+//g;
		unless ($verdict) { $verdict = 0; }
		if ($verdict =~ /^0/) {
			printerr "\nSAMPLE(S) selected : 'all samples'\n";
			$syntax = "select sampleid, chrom, count(*) from VarResult ";
			@sample = split(",", $SAMPLE{0});
		}else {
			@sample = split(",", $verdict);
			foreach (@sample) {
				if ($_ >= 1 && $_ <= $snumber) {
					$sample .= $SAMPLE{$_}.",";
				} else {
					printerr "ERROR:\t Sample number was not valid \n"; next MAINMENU;
				}
			} chop $sample;
			printerr "\nSAMPLE(S) selected: $sample\n";
			@sample = split(",",$sample);
			if ($#sample > 1) {
				@newsample = @sample[0..1];
			} else { @newsample = @sample;}
			$syntax = "select sampleid, chrom, count(*) from VarResult where sampleid in (";
			foreach (@newsample) { $syntax .= "'$_',";} chop $syntax; $syntax .= ") ";
		}
		$chromsyntax = "select distinct chrom from VarResult where sampleid in (";
		foreach (@sample) { $chromsyntax .= "'$_',";} chop $chromsyntax; $chromsyntax .= ") ";									 
		$chromsyntax .= "order by length(chrom), chrom";
		$t = Text::TabularDisplay->new(qw(SAMPLE CHROM VARIANTS SNPs INDELs));
		$sth = $dbh->prepare($chromsyntax);
		$sth->execute or die "SQL Error: $DBI::errstr\n";
		$number = 0;
		while (my $row = $sth->fetchrow_array() ) {
			$number++;
			$CHROM{$number} = $row;
		}
		$verdict = undef;
		print color ('bold');
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		foreach (sort {$a <=> $b} keys %CHROM) { print "  ", $_," :  $CHROM{$_}\n";}
		print color('bold');
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print "\nSelect chromosome (multiple chromosomes can be separated by comma or 0 for all) ? ";
	  chomp ($verdict = <>); print "\n";
		$verdict =~ s/\s+//g;
		unless ($verdict) { $verdict = 0; }
		unless ($verdict =~ /^0/) {
			unless ($syntax =~ /where/){ $syntax .= "where ("; }
			else { $syntax .= "and ("; }
			my @chromosomes = split(",", $verdict);
			foreach (@chromosomes) {
				$_ =int($_);
				if ($_ >= 1 && $_ <= $number) {
					$chromosome .= $CHROM{$_}.",";
				} else {
					printerr "ERROR:\t Chromosome number was not valid \n"; next MAINMENU;
				}
			} chop $chromosome;
			printerr "\nCHROMOSOME(S) selected : $chromosome\n";
		  @chromosomes = split(",", $chromosome);
			foreach (@chromosomes) { $syntax .= "chrom = '$_' or "; } $syntax = substr($syntax,0, -3); $syntax .= ") ";
		} else {
			printerr "\nCHROMOSOME(S) selected : 'all chromosomes'\n";
		}
		my $endsyntax = "group by sampleid, chrom order by sampleid, length(chrom),chrom";
		my $allsyntax = $syntax.$endsyntax; 
		$number = 0; 
		$sth = $dbh->prepare($allsyntax); 
		$sth->execute or die "SQL Error:$DBI::errstr\n";
		while (my ($sampleid, $chrom, $counted) = $sth->fetchrow_array() ) {
			$number++;
			$count++;
			$CHROM{$sampleid}{$number} = $chrom;
			$VARIANTS{$sampleid}{$chrom} = $counted;
		}
		$allsyntax = $syntax;
		unless ($allsyntax =~ /where/){ $allsyntax .= "where "; }
		else { $allsyntax .= "and "; }
		$allsyntax .= "variantclass = 'SNV' ".$endsyntax;
		$sth = $dbh->prepare($allsyntax); 
		$sth->execute or die "SQL Error:$DBI::errstr\n";
		while (my ($sampleid, $chrom, $counted) = $sth->fetchrow_array() ) {
			$SNPS{$sampleid}{$chrom} = $counted;
		}
		$allsyntax = $syntax;
		unless ($allsyntax =~ /where/){ $allsyntax .= "where "; }
		else { $allsyntax .= "and "; }
		$allsyntax .= "(variantclass = 'insertion' or variantclass = 'deletion') ".$endsyntax;
		$sth = $dbh->prepare($allsyntax);
		$sth->execute or die "SQL Error:$DBI::errstr\n";
		while (my ($sampleid, $chrom, $counted) = $sth->fetchrow_array() ) {
			$INDELS{$sampleid}{$chrom} = $counted;
		}
		$precount = 0;
		$indent = '';
		foreach my $ids (sort keys %VARIANTS){  
			if ($ids =~ /^[0-9a-zA-Z]/) {
				foreach my $no (sort {$a <=> $b} keys %{$CHROM{$ids} }) {
					if ($precount < 10) {
						@row = ();
						push @row, ($ids, $CHROM{$ids}{$no}, $VARIANTS{$ids}{$CHROM{$ids}{$no}});
						if (exists $SNPS{$ids}{$CHROM{$ids}{$no}}){
							push @row, $SNPS{$ids}{$CHROM{$ids}{$no}};
						}
						else {
							push @row, "0";
						}
						if (exists $INDELS{$ids}{$CHROM{$ids}{$no}}){
							push @row, $INDELS{$ids}{$CHROM{$ids}{$no}};
						}
						else {
							push @row, "0";
						}
					} else { $indent = "Only"; next;} #adding the ten count conditionality
					$precount++;
					$t->add(@row);
				}
			}
		}
	} elsif ($number == 0){
		printerr "\nERROR:\tEmpty dataset, import Variant Information using tad-import.pl -data2db\n"; next MAINMENU;
	} else {
		printerr "ERROR:\t Organism number was not valid \n"; next MAINMENU;
	}

	print colored("$precount out of $count results displayed.", 'underline'), "\n";
	print LOG "$precount out of $count results displayed.\n";
	printerr $t-> render, "\n\n"; #print results
	
	my ($dchromosome, $dsamples);
	if ($chromosome) {$dchromosome = "--chromosome '$chromosome'";}
	if ($sample) {$dsamples = " --samples '$sample'";}
	print color('bright_black');
	print "---------------------------ADDITIONAL PROCEDURE---------------------------\n";
	print "--------------------------------------------------------------------------\n";
	print "NOTICE:\t $indent $precount sample(s) displayed.\n";
	print "PLEASE RUN EITHER THE FOLLOWING COMMANDS TO VIEW OR EXPORT THE COMPLETE RESULT.\n";
	print "\ttad-export.pl --db2data --chrvar --species '$species' $dchromosome$dsamples\n";
	print "\ttad-export.pl --db2data --chrvar --species '$species' $dchromosome$dsamples --output output.txt\n";
	print "--------------------------------------------------------------------------\n";
	print "--------------------------------------------------------------------------\n";
	print color('reset');
	print LOG "---------------------------ADDITIONAL PROCEDURE---------------------------\n";
	print LOG "--------------------------------------------------------------------------\n";
	print LOG "NOTICE:\t $indent $precount sample(s) displayed.\n";
	print LOG "PLEASE RUN EITHER THE FOLLOWING COMMANDS TO VIEW OR EXPORT THE COMPLETE RESULT.\n";
	print LOG "\ttad-export.pl --db2data --chrvar --species '$species' $dchromosome$dsamples\n";
	print LOG "\ttad-export.pl --db2data --chrvar --species '$species' $dchromosome$dsamples --output output.txt\n";
	print LOG "--------------------------------------------------------------------------\n";
	print LOG "--------------------------------------------------------------------------\n";
	printerr "\n\n";
}

sub VARANNO {
	open(LOG, ">>", $_[2]) or die "\nERROR:\t cannot write LOG information to log file $_[1] $!\n";
	print colored("G.\tGENE ASSOCIATED VARIANTS ANNOTATION.", 'bright_red on_black'),"\n";
	print LOG "G.\tGENE ASSOCIATED VARIANTS ANNOTATION.\n";
	
	$dbh = $_[0]; $ibis = $_[4];
	my $vfastbit = $_[1]."/variant-information";
	my ($genes, $genes2, %ORGANISM, %GENEVAR, @genes, $indent, $species, $vfound);

	$count = 0;
	$sth = $dbh->prepare("select distinct a.organism from vw_sampleinfo a join VarSummary b on a.sampleid = b.sampleid"); #get organism with annotation information
	$sth->execute or die "SQL Error: $DBI::errstr\n";
	my $number = 0;
	while (my $row = $sth->fetchrow_array() ) {
		$number++; #print "myrow $row\n\n";
		$ORGANISM{$number} = $row;
	}
	if ($number > 1) {
		print color ('bold');
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print "\nThe following organisms are available; select an organism : \n";
		foreach (sort {$a <=> $b} keys %ORGANISM) { print "  ", $_,"\.  $ORGANISM{$_}\n";}
		print color('bold');
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print "\n ? : ";
		chomp ($verdict = int(<>)); print "\n";
	} else { $verdict = 1; } # else if there's only one organism
	if ($verdict >= 1 && $verdict <= $number ) {
		$species = $ORGANISM{$verdict};
		printerr "\nORGANISM : $species\n";
		$verdict = undef;
		print "\nSelect genes (multiple genes can be separated by comma) ? "; #ask for genes
	  chomp ($verdict = uc(<>)); 
		$verdict =~ s/\s+//g;
		unless ($verdict) { printerr "ERROR:\t Gene(s) not provided\n"; next MAINMENU; } # if genes aren't provided
		$genes = undef;
		printerr "\nGENE(S) selected : $verdict\n";
		@genes = split(",", $verdict);
		$sth = $dbh->prepare("select group_concat(distinct a.nosql) from VarSummary a join vw_sampleinfo b on a.sampleid = b.sampleid where b.organism = '$species' and a.nosql is not null group by a.nosql");$sth->execute(); my $found =$sth->fetch();
		$sth = $dbh->prepare("select group_concat(distinct annversion) from VarSummary a join vw_sampleinfo b on a.sampleid = b.sampleid where annversion is not null and b.organism = '$species' group by annversion");
		$sth->execute(); $vfound =$sth->fetch();
		unless ($vfound) {
			printerr "NOTICE:\t There are no gene-associated variant annotation for '$species', import using using tad-import.pl\n";
		} else {
			foreach my $gene (@genes){
				if ($found) {
					#using fastbit
					my $syntax = "$ibis -d $vfastbit -q \"select chrom,position,refallele,altallele,variantclass,consequence,group_concat(genename),group_concat(dbsnpvariant), 	group_concat(sampleid) where genename like '%".$gene."%' and organism='$species'\" -o $_[3]";
					`$syntax 2>> $_[2]`;
					open(IN,'<',$_[3]); my @nosqlcontent = <IN>; close IN; `rm -rf $_[3]`;
					if ($#nosqlcontent < 0) {printerr "NOTICE:\t No variants are associated with gene '$gene'\n";}
					else {
						foreach (@nosqlcontent) {
							chomp;
							$count++;
							my @arraynosqlA = split (",",$_,3); foreach (@arraynosqlA[0..1]) { $_ =~ s/"//g;}
							my @arraynosqlB = split("\", \"", $arraynosqlA[2]); foreach (@arraynosqlB) { $_ =~ s/"//g ; $_ =~ s/NULL/-/g;}
							my @arraynosqlC = uniq(sort(split(", ", $arraynosqlB[4]))); if ($#arraynosqlC > 0 && $arraynosqlC[0] =~ /^-/){ shift @arraynosqlC; }
							my @arraynosqlD = uniq(sort(split(", ", $arraynosqlB[5]))); if ($#arraynosqlD > 0 && $arraynosqlD[0] =~ /^-/){ shift @arraynosqlD; }
							push my @row, @arraynosqlA[0..1], @arraynosqlB[0..3], join(",", @arraynosqlC) , join(",", @arraynosqlD), join (",", uniq(sort(split (", ", $arraynosqlB[6]))));
							$GENEVAR{$gene}{$arraynosqlA[0]}{$arraynosqlA[1]}{$arraynosqlB[3]} = [@row];
						}
						$genes2 .= $gene.",";
					}
					$genes .= $gene.",";
				} else {
					#using mysql
					my $newcount = 0;
					my $syntax = "call usp_vgene(\"".$species."\",\"".$gene."\")"; 
					$sth = $dbh->prepare($syntax);
					$sth->execute or die "SQL Error: $DBI::errstr\n";
					while (my @row = $sth->fetchrow_array() ) {
						$count++; $newcount++;
					 	$GENEVAR{$gene}{$row[0]}{$row[1]}{$row[5]} = [@row];
					}
					if ($newcount > 0) { $genes2 .= $gene.","; } else { printerr "NOTICE:\t No variants are associated with gene '$gene'\n"; } #if gene is in the database
					$genes .= $gene.",";
				}
			} chop $genes; chop $genes2;
		}
	} elsif ($number == 0){
		printerr "\nERROR:\tEmpty dataset, import Variant Information using tad-import.pl -data2db\n"; next MAINMENU;
	} else {
		printerr "ERROR:\t Organism number was not valid \n"; next MAINMENU;
	}
  $t = Text::TabularDisplay->new(qw(Chrom Position Refallele Altallele Variantclass Consequence Genename Dbsnpvariant Sampleid)); #header
	$precount = 0;
	my ($odacount, $endcount) = (0,10);
	if ($#genes >= 1){ $endcount = 5*($#genes+1);}
	foreach my $aa (keys %GENEVAR){ #preset to 10 rows	
		unless ($precount >= $endcount) {
			if ($#genes >= 1) { if ($odacount == 5) {	$odacount = 0;} }
			foreach my $bb (natsort keys % {$GENEVAR{$aa} }){
				unless ($precount >= $endcount) {
					if ($#genes >= 1) { if ($odacount == 5) { last; } }		
					foreach my $cc (sort {$a <=> $b} keys % {$GENEVAR{$aa}{$bb} }) {
						unless ($precount >= $endcount) {
							if ($#genes >= 1) { if ($odacount == 5) { last; } }
							foreach my $dd (sort keys % {$GENEVAR{$aa}{$bb}{$cc} }) {
								unless ($precount >= $endcount) {
									if ($#genes >= 1) { if ($odacount == 5) { last; } }
									$precount++; $odacount++;
									$t->add($GENEVAR{$aa}{$bb}{$cc}{$dd});
								}
							}
						}
					}
				}
			}
		}
  }
	if ($precount >= $count) {
		$indent = "";
	} else {
		$indent = "Only";
	}
	if ($vfound) {
		print colored("$precount out of $count results displayed", 'underline'), "\n";
		print LOG "$precount out of $count results displayed\n";
		printerr $t-> render, "\n\n"; #print display
		
		if ($count >0 ) {
			print color('bright_black'); #additional procedure
			print "---------------------------ADDITIONAL PROCEDURE---------------------------\n";
			print "--------------------------------------------------------------------------\n";
			print "NOTICE:\t $indent $precount sample(s) displayed.\n";
			print "PLEASE RUN EITHER THE FOLLOWING COMMANDS TO VIEW OR EXPORT THE COMPLETE RESULT.\n";
			print "\ttad-export.pl --db2data --varanno --species '$species' --gene '$genes2' \n";
			print "\ttad-export.pl --db2data --varanno --species '$species' --gene '$genes2' --output output.txt\n";
			print "--------------------------------------------------------------------------\n";
			print "--------------------------------------------------------------------------\n";
			print color('reset');
			# print to log file
			print LOG "---------------------------ADDITIONAL PROCEDURE---------------------------\n";
			print LOG "--------------------------------------------------------------------------\n";
			print LOG "NOTICE:\t $indent $precount sample(s) displayed.\n";
			print LOG "PLEASE RUN EITHER THE FOLLOWING COMMANDS TO VIEW OR EXPORT THE COMPLETE RESULT.\n";
			print LOG "\ttad-export.pl --db2data --varanno --species '$species' --gene '$genes2' \n";
			print LOG "\ttad-export.pl --db2data --varanno --species '$species' --gene '$genes2' --output output.txt\n";
			print LOG "--------------------------------------------------------------------------\n";
			print LOG "--------------------------------------------------------------------------\n";
			printerr "\n\n";
		} else {
			printerr "NOTICE:\t No Results based on search criteria: $genes\n";
		}
	}
}

sub CHRANNO {
	open(LOG, ">>", $_[2]) or die "\nERROR:\t cannot write LOG information to log file $_[1] $!\n";
	print colored("H.\tCHROMSOMAL REGIONS WITH VARIANTS & ANNOTATION.", 'bright_red on_black'),"\n";
	print LOG "H.\tCHROMSOMAL REGIONS WITH VARIANTS & ANNOTATION.\n";
	$dbh = $_[0]; $ibis = $_[4];
	my $vfastbit = $_[1]."/variant-information";
	my ($chromosome, %ORGANISM, %CHRVAR, %CHROM, @chromosomes, $species,$indent,$region);
	my $syntax = "$ibis -d $vfastbit -q \"select chrom,position,refallele,altallele,variantclass,consequence,group_concat(genename),group_concat(dbsnpvariant), group_concat(sampleid) where ";
	$count = 0;
	$sth = $dbh->prepare("select distinct a.organism from vw_sampleinfo a join VarSummary b on a.sampleid = b.sampleid"); #get organism with annotation information
	$sth->execute or die "SQL Error: $DBI::errstr\n";
	my $number = 0;
	while (my $row = $sth->fetchrow_array() ) {
		$number++;
		$ORGANISM{$number} = $row;
	}
	if ($number > 1) {
		print color ('bold');
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print "\nThe following organisms are available; select an organism : \n";
		foreach (sort {$a <=> $b} keys %ORGANISM) { print "  ", $_,"\.  $ORGANISM{$_}\n";}
		print color('bold');
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print "\n ? : ";
		chomp ($verdict = int(<>)); print "\n";
	} else { $verdict = 1; } # else if there's only one organism
	if ($verdict >= 1 && $verdict <= $number ) {
		$species = $ORGANISM{$verdict};
		$syntax .= "organism='$species'";
		printerr "\nORGANISM : $species\n";
		$sth = $dbh->prepare("select group_concat(distinct a.nosql) from VarSummary a join vw_sampleinfo b on a.sampleid = b.sampleid where b.organism = '$species' and a.nosql is not null group by a.nosql");$sth->execute(); my $found =$sth->fetch();
		$verdict = undef;
		$sth = $dbh->prepare("select distinct chrom from VarResult where sampleid = (select a.sampleid from VarSummary a join vw_sampleinfo b on a.sampleid = b.sampleid where b.organism = '$species' order by a.date desc limit 1) order by length(chrom), chrom");
		$sth->execute or die "SQL Error: $DBI::errstr\n";
		$number = 0;
		while (my $row = $sth->fetchrow_array() ) {
			$number++;
			$CHROM{$number} = $row;
		}
		print color ('bold');
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		foreach (sort {$a <=> $b} keys %CHROM) { print "  ", $_," :  $CHROM{$_}\n";}
		print color('bold');
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print "\nSelect chromosome (multiple chromosomes can be separated by comma or 0 for all) ? ";
	  chomp ($verdict = <>); print "\n";
		$verdict =~ s/\s+//g;
		unless ($verdict) { $verdict = 0; }
		unless ($verdict =~ /^0/) {
			$syntax .= " and ";
			@chromosomes = split(",",$verdict);
			if ($#chromosomes > 0) {
				foreach (@chromosomes){
					$_ = int($_);
					if ($_ >= 1 && $_ <= $number) {
						$chromosome .= $CHROM{$_}.",";
					} else {
						printerr "ERROR:\tChromosome  number was not valid \n"; next MAINMENU;
					}
				} chop $chromosome;
				printerr "\nCHROMOSOME(S) selected : $chromosome\n";
				@chromosomes = split(",", $chromosome);
				if ($found) {foreach (@chromosomes) { $syntax .= "chrom = '$_' or "; } $syntax = substr($syntax, 0, -3); } # if the content has nosql component
				else {
					foreach (@chromosomes) {
						$syntax = "call usp_vchrom(\"".$species."\",\"".$_."\")";
						$sth = $dbh->prepare($syntax);
						$sth->execute or die "SQL Error: $DBI::errstr\n";
						while (my @row = $sth->fetchrow_array() ) {
							$count++;
							if ($row[5] =~ /^-/){ $row[5] = ''; }
							$CHRVAR{$row[0]}{$row[1]}{$row[5]} = [@row];
						}
						unless ($count>0) {printerr "NOTICE:\t No variants are associated with chromosome '$_' \n";}
					}	
				}
			} else {
				my ($start, $stop) = (0,0);
				$_ = int($chromosomes[0]);
				if ($_ >= 1 && $_ <= $number) {
					$chromosome = $CHROM{$_};
				} else {
					printerr "ERROR:\tChromosome  number was not valid \n"; next MAINMENU;
				}
				printerr "\nCHROMOSOME(S) selected : $chromosome\n";
				$syntax .= "chrom = '$chromosome' and ";
				print "\nSpecify region of interest (eg: 10000-500000) or 0 for the entire chromosome. ? "; #ask for region
				chomp ($verdict = <>); 
				$verdict =~ s/\s+//g;
				if ($verdict) {
					if ($verdict =~ /\-/) {
						($start, $stop) = split("-", $verdict);
						$syntax .= "position between $start and $stop ";
						$region = "--region ".$start."-".$stop;
						printerr "\nREGION specified : between $start and $stop\n";
					} else {
						$start = $verdict-1500; $stop = $verdict+1500;
						$syntax .= "position between ". $start." and ". $stop;
						$region = "--region ".$start."-".$stop;
						printerr "\nREGION specified : 3000bp region of $verdict\n";
					}
					unless($found) {
						$syntax = "call usp_vchrposition(\"".$species."\",\"".$chromosome."\",\"".$start."\",\"".$stop."\")";
						$sth = $dbh->prepare($syntax);
						$sth->execute or die "SQL Error: $DBI::errstr\n";
						while (my @row = $sth->fetchrow_array() ) {
							$count++;
							if ($row[5] =~ /^-/){ $row[5] = ''; }
							$CHRVAR{$row[0]}{$row[1]}{$row[5]} = [@row];
						}
						unless ($count>0) {printerr "NOTICE:\t No variants are associated with chromosomal location '$chromosome:$start\-$stop' \n";}
					}
				} else {
					unless($found) {
						$syntax = "call usp_vchrom(\"".$species."\",\"".$chromosome."\")";
						$sth = $dbh->prepare($syntax);
						$sth->execute or die "SQL Error: $DBI::errstr\n";
						while (my @row = $sth->fetchrow_array() ) {
							$count++;
							if ($row[5] =~ /^-/){ $row[5] = ''; }
							$CHRVAR{$row[0]}{$row[1]}{$row[5]} = [@row];
						}
						unless ($count>0) {printerr "NOTICE:\t No variants are associated with chromosome '$chromosome'\n";}
					}
				}# end region specified
			}
		} else {
			printerr "\nCHROMOSOME(S) selected : 'all chromosomes'\n";
			unless($found) {
				$syntax = "call usp_vall(\"".$species."\")";
				$sth = $dbh->prepare($syntax);
				$sth->execute or die "SQL Error: $DBI::errstr\n";
				while (my @row = $sth->fetchrow_array() ) {
					$count++;
					if ($row[5] =~ /^-/){ $row[5] = ''; }
					$CHRVAR{$row[0]}{$row[1]}{$row[5]} = [@row];
				}
				if ($count >0) {printerr "NOTICE:\t No variants are associated with '$species'\n";}		
			}
		}
		if ($found) {
			$syntax .= "\" -o $_[3]"; 
			`$syntax 2>> $_[2]`;
			open(IN,'<',$_[3]); my @nosqlcontent = <IN>; close IN; `rm -rf $_[3]`;
			if ($#nosqlcontent < 0) {printerr "NOTICE:\t No variants are associated with chromosomal location \n";}
			else {
				foreach (@nosqlcontent) {
					chomp;
					$count++;
					my @arraynosqlA = split (",",$_,3); foreach (@arraynosqlA[0..1]) { $_ =~ s/"//g;}
					my @arraynosqlB = split("\", \"", $arraynosqlA[2]); foreach (@arraynosqlB) { $_ =~ s/"//g ; $_ =~ s/NULL/-/g;}
					my @arraynosqlC = uniq(sort(split(", ", $arraynosqlB[4]))); if ($#arraynosqlC > 0 && $arraynosqlC[0] =~ /^-/){ shift @arraynosqlC; }
					my @arraynosqlD = uniq(sort(split(", ", $arraynosqlB[5]))); if ($#arraynosqlD > 0 && $arraynosqlD[0] =~ /^-/){ shift @arraynosqlD; }
					push my @row, @arraynosqlA[0..1], @arraynosqlB[0..3], join(",", @arraynosqlC) , join(",", @arraynosqlD), join (",", uniq(sort(split (", ", $arraynosqlB[6]))));
					$CHRVAR{$arraynosqlA[0]}{$arraynosqlA[1]}{$arraynosqlB[3]} = [@row];
				}
			}
		}
	} elsif ($number == 0){
		printerr "\nERROR:\tEmpty dataset, import Variant Information using tad-import.pl -data2db\n"; next MAINMENU;
	} else {
		printerr "ERROR:\t Organism number was not valid \n"; next MAINMENU;
	}
  $t = Text::TabularDisplay->new(qw(Chrom Position Refallele Altallele Variantclass Consequence Genename Dbsnpvariant Sampleid)); #header
	$precount = 0;
	my ($odacount, $endcount) = (0,10);
	if ($#chromosomes >= 1){ $endcount = 5*($#chromosomes+1);}
	foreach my $aa (natsort keys %CHRVAR){ #preset to 10 rows	
		unless ($precount >= $endcount) {
			if ($#chromosomes >= 1) { if ($odacount == 5) {	$odacount = 0;} }
			foreach my $bb (sort {$a <=> $b} keys % {$CHRVAR{$aa} }){
				unless ($precount >= $endcount) {
					if ($#chromosomes >= 1) { if ($odacount == 5) { last; } }
					foreach my $cc (sort {$a cmp $b || $a <=> $b} keys % {$CHRVAR{$aa}{$bb} }){
						unless ($precount >= $endcount) {
							if ($#chromosomes >= 1) { if ($odacount == 5) { last; } }	
							$precount++; $odacount++;
							$t->add($CHRVAR{$aa}{$bb}{$cc});
						}
					}
				}
			}
		}
  }
	if ($precount >= $count) {
		$indent = "";
	} else {
		$indent = "Only";
	}

	print colored("$precount out of $count results displayed", 'underline'), "\n";
	print LOG "$precount out of $count results displayed.\n";
	printerr $t-> render, "\n\n"; #print results
	
	my ($dchromosome);
	if ($chromosome) {
		$dchromosome = "--chromosome '$chromosome'";
		if ($region) { $dchromosome .= " ".$region; }
	}
	if ($count >0 ) {
		print color('bright_black'); #additional procedure
		print "---------------------------ADDITIONAL PROCEDURE---------------------------\n";
		print "--------------------------------------------------------------------------\n";
		print "NOTICE:\t $indent $precount sample(s) displayed.\n";
		print "PLEASE RUN EITHER THE FOLLOWING COMMANDS TO VIEW OR EXPORT THE COMPLETE RESULT.\n";
		print "\ttad-export.pl --db2data --varanno --species '$species' $dchromosome \n";
		print "\ttad-export.pl --db2data --varanno --species '$species' $dchromosome --output output.txt\n";
		print "--------------------------------------------------------------------------\n";
		print "--------------------------------------------------------------------------\n";
		print color('reset');
		print LOG "---------------------------ADDITIONAL PROCEDURE---------------------------\n";
		print LOG "--------------------------------------------------------------------------\n";
		print LOG "NOTICE:\t $indent $precount sample(s) displayed.\n";
		print LOG "PLEASE RUN EITHER THE FOLLOWING COMMANDS TO VIEW OR EXPORT THE COMPLETE RESULT.\n";
		print LOG "\ttad-export.pl --db2data --varanno --species '$species' $dchromosome \n";
		print LOG "\ttad-export.pl --db2data --varanno --species '$species' $dchromosome --output output.txt\n";
		print LOG "--------------------------------------------------------------------------\n";
		print LOG "--------------------------------------------------------------------------\n";
		printerr "\n\n";
	} else {
		printerr "NOTICE:\t No Results based on search criteria: $chromosome:".substr($region,9,-1)."\n";
	}
}
1;
