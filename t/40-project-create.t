use strict;
use Test::More;
use Test::Exception;

use FindBin qw< $Bin >;
use lib $Bin;
use TestLib;

use Accounting::Kitty;

my $ak = TestLib::kitty(populate => 1);

subtest 'project creation' => sub {
   my $project;
   lives_ok {
      $project = $ak->create_project(
         {
            name  => 'Busto',
            data  => 'whatever',
         }
      );
   } ## end lives_ok
   'account creation lives';

   my $created = $ak->fetch(Project => $project->id());
   ok $created, 'retrieved created project';

   is $created->name(),  'Busto',    'name';
   is $created->data(),  'whatever', 'data';
};

done_testing();
