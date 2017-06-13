#package CC::Create;
use strict;
use Cwd qw(abs_path);
use DBD::mysql;
use IO::File;

sub DEFAULTS {
  my $default = "https://github.com/modupeore/TransAtlasDB";
  return $default;
}

sub fastbit_name {
  my $ibis = `which ibis`; $ibis = &clean($ibis);
  my $ardea = `which ardea`; $ardea = &clean($ardea);
  return $ibis, $ardea;
}

sub clean {
  $_[0] =~ s/^\s+|\s+$//g;
  return $_[0];
}

sub mysql_create {
  my $dsn = 'dbi:mysql:host=localhost;port=3306';
  my $dbh = DBI -> connect($dsn, $_[1], $_[2]) or die "Connection Error: $DBI::errstr\n";
  return $dbh;
}

sub mysql {
  my $dsn = 'dbi:mysql:database='.$_[0].';host=localhost;port=3306';
  my $dbh = DBI -> connect($dsn, $_[1], $_[2]) or die "\nConnection Error: Database $_[0] doesn't exist. Run 'INSTALL-tad.pL' first\n";
  return $dbh;
}

sub fastbit {
  my $ffastbit = "$_[0]/$_[1]";
  return $ffastbit;
}

sub connection {
  our %DBS = ("MySQL", 1,"FastBit", 2,);
  our %interest = ("username", 1, "password", 2, "databasename", 3, "path", 4, "foldername", 5, "ibis", 6, "ardea", 7);
  my %ALL;
  open (CONTENT, $_[0]) or die "Error: Can't open connection file. Run 'connect-tad.pL'\n"; 
  my @contents = <CONTENT>; close (CONTENT);
  my $nameofdb; 
  foreach (@contents){
    chomp;
    if(/\S/){
      $_= &clean($_);
      if (exists $DBS{$_}) {
        $nameofdb = $_;
      }
      else {
        my @try = split " ";
        if (exists $interest{$try[0]}){
          if ($try[1]) {
            $ALL{"$nameofdb-$try[0]"} = $try[1];
          }
          else { pod2usage("Error: \"$nameofdb-$try[0]\" option in $_[0] file is blank"); }
        }
        else {
          die "Error: variable $try[0] is not a valid argument consult template $_[1]";
        }
      }
    }
  } 
  return \%ALL;
}
sub open_unique {
    my $file = shift || '';
    unless ($file =~ /^(.*?)(\.[^\.]+)$/) {
        print "Bad file name: '$file'\n";
        return;
    }
    my $io;
    my $seq = '';
    my $base = $1;
    my $ext = $2;
    until (defined ($io = IO::File->new($base.$seq.$ext
                                   ,O_WRONLY|O_CREAT|O_EXCL))) {
        last unless $!{EEXIST};
        $seq = '_0' if $seq eq '';
        $seq =~ s/(\d+)/$1 + 1/e;
    }
    return [$io,$base.$seq.$ext] if defined $io;
}

sub printerr {
  print STDERR @_;
  print LOG @_;
}

1;
