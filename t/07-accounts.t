use strict;
use Test::More;
use Test::Exception;
use 5.010;

use FindBin qw< $Bin >;
use lib $Bin;
use TestLib;

use Accounting::Kitty;

my $ak = TestLib::kitty(populate => 1);

my @accounts;
lives_ok { @accounts = $ak->accounts() } 'get list of accounts';
is scalar(@accounts), 8, 'number of accounts';

my $foo;
lives_ok {
   ($foo) = grep { $_->name() eq 'Foo' } @accounts;
}
'method name() works on retrieved accounts';
is $foo->id(), 3, 'id of Foo account';

my ($bar, @rest);
lives_ok { ($bar, @rest) = $ak->accounts({name => 'Bar'}) }
'pass query to accounts()';
is $bar->id(), 4, 'id of Bar account';

done_testing();
