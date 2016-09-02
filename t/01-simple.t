use strict;
use Test::More;
use Test::Exception;
use 5.010;

use FindBin qw< $Bin >;
use lib $Bin;
use TestLib;

use Accounting::Kitty;

my $ak = TestLib::kitty()
  or BAIL_OUT 'no testing without an Accounting::Kitty object';
TestLib::populate($ak);

my ($external, $common, $transfer, @rest);
lives_ok {
   ($external, $common, $transfer, @rest) = $ak->fetch(
      Account  => 1,
      Account  => {name => 'Common'},
      Transfer => {title => 'titolo'},
   );
} ## end lives_ok
'fetch two accounts and one transfer';
ok $external && $common && $transfer, 'objects are populated';
is scalar(@rest), 0, 'nothing spurious was fetched';

is $external->name(), 'External', 'name of account n. 1';
is $common->id(),     2,          'id of account Common';
is $transfer->description(), 'descrizione',
  'description of transfer with title "titolo"';

my @accounts;
lives_ok { @accounts = $ak->accounts() } 'get list of accounts';
is scalar(@accounts), 8, 'number of accounts';

# FIXME move into separate file
my $foo;
lives_ok {
   ($foo) = grep { $_->name() eq 'Foo' } @accounts;
}
'method name() works on retrieved accounts';
is $foo->id(), 3, 'id of Foo account';

my $bar;
lives_ok { ($bar, @rest) = $ak->accounts({name => 'Bar'}) }
'pass query to accounts()';
is $bar->id(), 4, 'id of Bar account';

done_testing();
