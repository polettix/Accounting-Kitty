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

my $project;
lives_ok { $project = $ak->fetch(Project => 1) } 'fetch project';
isa_ok $project, 'Accounting::Kitty::Result::Project';

subtest 'basic characteristics of the project no. 1' => sub {
   is $project->id(),   1,               'id';
   is $project->name(), 'BazProject1',   'key';
   is $project->data(), 'whateverables', 'data';
};

subtest accounts => sub {
   my @accounts;
   lives_ok { @accounts = $project->accounts() } 'get accounts of project';
   is scalar(@accounts), 4, 'four accounts retrieved for project';
   isa_ok $_, 'Accounting::Kitty::Result::Account' for @accounts;

   my %names = map { $_->name() => 1 } @accounts;
   is_deeply \%names, {External => 1, Common => 1, Foo => 1, Bar => 1},
     'accounts names';
};

subtest owners => sub {
   my @owners;
   lives_ok { @owners = $project->owners() } 'get owners for project';
   is scalar(@owners), 2, 'two owners retrieved for project';
   isa_ok $_, 'Accounting::Kitty::Result::Owner' for @owners;

   my %names = map { $_->key() => 1 } @owners;
   is_deeply \%names, {FooOwner => 1, BarOwner => 1},
     'owners names';
};

my $hash = {
   id => 1,
   name => 'BazProject1',
   data => 'whateverables',
};
is_deeply scalar($project->as_hash()), $hash, 'as_hash';
is_deeply $project->TO_JSON(), $hash, 'TO_JSON';

done_testing();
