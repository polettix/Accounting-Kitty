package TestLib;
use strict;
use warnings;
use 5.010;
{ our $VERSION = '0.001'; }

use Exporter 'import';
our @EXPORT_OK = qw< kitty populate >;

sub kitty {
   my %opts  = @_;
   my $dsn   = $opts{dsn} // 'dbi:SQLite:dbname=:memory:';
   my $check = $opts{check} // 0;
   return eval {
      require Accounting::Kitty;
      my $retval = Accounting::Kitty->connect(
         $dsn, '', '',
         {
            RaiseError => 1,
            PrintError => 0,
         }
      );
      $retval->initialize_tables(check => $check);
      populate($retval) if $opts{populate};
      $retval;
   } || do {
      warn $@;
      undef;
   };
} ## end sub kitty

sub populate {
   my ($ak) = @_;
   $ak->storage()->dbh()->do($_) for split m{(?mxs:;$)}, <<END_OF_SQL;

INSERT INTO "owner" VALUES
   (1, 'FooOwner', 'whatever', -6000),
   (2, 'BarOwner', 'xoxo',     6000);

INSERT INTO "project" VALUES
   (1, 'BazProject1', 'whateverables'),
   (2, 'BazProject2', 'befurg'),
   (3, 'BazProject3', 'BEFURG');

INSERT INTO "account" VALUES
   (1, NULL, 1, 'External',  'service', -1000),
   (2, NULL, 1, 'Common',    'service', 1000),
   (3, 1,    1, 'Foo',       'owned',   -6000),
   (4, 2,    1, 'Bar',       'owned',   6000),
   (5, 1,    2, 'FooOther',  'owned',   0),
   (6, 2,    2, 'BarOther',  'owned',   0),
   (7, NULL, 2, 'CommonX',   'service', 0),
   (8, NULL, 2, 'ExternalX', 'service', 0);

INSERT INTO "quota" VALUES
   (1, 'fifty-fifty', 3, 1),
   (2, 'fifty-fifty', 4, 1),
   (3, '100% Foo',    3, 1),
   (4, '100% Bar',    4, 1);

INSERT INTO "transfer" VALUES
  (1,1,2,1000,'2009-02-13 23:31:30','titolo','descrizione',1,NULL),
  (2,3,4,6000,'2009-02-13 23:31:30','foo to bar','whatever',2,NULL),

  (3,7,8,6000,'2009-02-13 23:31:30','foo to bar','whatever',3,NULL),
  (4,5,7,4000,'2009-02-13 23:31:30','foo to bar','whatever',3,NULL),
  (5,6,7,2000,'2009-02-13 23:31:30','foo to bar','whatever',3,NULL);

END_OF_SQL
} ## end sub populate

1;
