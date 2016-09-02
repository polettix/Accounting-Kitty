# inspired by:
# http://perltricks.com/article/208/2016/1/5/Save-time-with-compile-tests
use strict;
use Test::More;
use Test::Exception;

use FindBin qw< $Bin >;
use lib $Bin;
use TestLib;

use Accounting::Kitty;

my $ak;
lives_ok {
   $ak = Accounting::Kitty->connect(
      'dbi:SQLite:dbname=:memory:',
      '', '',
      {
         RaiseError => 1,
         PrintError => 0
      }
   );
} ## end lives_ok
'Account::Kitty object instantiation'
  or BAIL_OUT('no point in testing without an Account::Kitty object');

lives_ok { $ak->initialize_tables() } 'database tables creation'
  or BAIL_OUT('no point in testing without a proper test database');
lives_ok { $ak->initialize_tables() }
'database tables re-creation avoidance';
throws_ok { $ak->initialize_tables(check => 0) } qr{table.*already exists},
  'database tables re-creation without checking';

done_testing();
