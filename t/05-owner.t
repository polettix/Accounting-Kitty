use strict;
use Test::More;
use Test::Exception;

use FindBin qw< $Bin >;
use lib $Bin;
use TestLib;

use Accounting::Kitty;

my $ak = TestLib::kitty()
  or BAIL_OUT 'no testing without an Accounting::Kitty object';
TestLib::populate($ak);

my $owner;
lives_ok { $owner = $ak->fetch(Owner => 1) } 'fetch owner';
isa_ok $owner, 'Accounting::Kitty::Result::Owner';

subtest 'basic characteristics of the owner no. 1' => sub {
   is $owner->id(),    1,          'id';
   is $owner->key(),   'FooOwner', 'key';
   is $owner->data(),  'whatever', 'data';
   is $owner->total(), -6000,      'total';
};

subtest accounts => sub {
   my @accounts;
   lives_ok { @accounts = $owner->accounts() } 'get accounts for owner';
   is scalar(@accounts), 2, 'two accounts retrieved for owner';
   isa_ok $_, 'Accounting::Kitty::Result::Account' for @accounts;

   my %names = map { $_->name() => 1 } @accounts;
   is_deeply \%names, {Foo => 1, FooOther => 1}, 'accounts names';
};

subtest projects => sub {
   my @projects;
   lives_ok { @projects = $owner->projects() } 'get projects for owner';
   is scalar(@projects), 2, 'two projects retrieved for owner';
   isa_ok $_, 'Accounting::Kitty::Result::Project' for @projects;

   my %names = map { $_->name() => 1 } @projects;
   is_deeply \%names, {BazProject1 => 1, BazProject2 => 1},
     'projects names';
};

my $hash = {
   id    => 1,
   key   => 'FooOwner',
   data  => 'whatever',
   total => -6000,
};
is_deeply scalar($owner->as_hash()), $hash, 'as_hash';
is_deeply $owner->TO_JSON(), $hash, 'TO_JSON';

done_testing();
