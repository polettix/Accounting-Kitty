package Accounting::Kitty::Result::Project;

use utf8;
use strict;
use warnings;
{ our $VERSION = '0.001'; }

use base 'DBIx::Class::Core';

__PACKAGE__->table('project');

__PACKAGE__->add_columns(
   id => {
      data_type         => 'integer',
      is_auto_increment => 1,
      is_numeric        => 1,
      is_nullable       => 0
   },
   name => {data_type => 'text', is_nullable => 1},
   data => {data_type => 'text', is_nullable => 1}
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many(
   accounts => 'Accounting::Kitty::Result::Account',
   {'foreign.project_id' => 'self.id'},
   {cascade_copy         => 0, cascade_delete => 0},
);

__PACKAGE__->many_to_many(owners => accounts => 'owner');

sub as_hash {
   my $self = shift;
   my %cols = $self->get_columns();
   return %cols if wantarray();
   return \%cols;
} ## end sub as_hash

sub quota_finances {
   my @retval = map { $_->quota_finances() } shift->accounts();
   return @retval if wantarray();
   return \@retval;
}

sub quotas {
   my @retval = map { $_->quotas() } shift->accounts();
   return @retval if wantarray();
   return \@retval;
}

sub quotas_any {
   my $self = shift;
   my @retval = ($self->quotas(), $self->quota_finances());
   return @retval if wantarray();
   return \@retval;
}

sub TO_JSON { return scalar(shift->as_hash()) }

1;
