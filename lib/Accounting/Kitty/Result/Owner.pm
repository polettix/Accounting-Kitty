package Accounting::Kitty::Result::Owner;

use utf8;
use strict;
use warnings;
{ our $VERSION = '0.001'; }

use base 'DBIx::Class::Core';

__PACKAGE__->table('owner');

__PACKAGE__->add_columns(
   id => {
      data_type         => 'integer',
      is_auto_increment => 1,
      is_numeric        => 1,
      is_nullable       => 0
   },
   key   => {data_type => 'text', is_nullable => 0},
   data  => {data_type => 'text', is_nullable => 1},
   total => {
      data_type     => 'integer',
      is_nullable   => 0,
      is_numeric    => 1,
      default_value => 0
   },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many(
   accounts => 'Accounting::Kitty::Result::Account',
   {'foreign.owner_id' => 'self.id'},
   {cascade_copy       => 0, cascade_delete => 0},
);

__PACKAGE__->many_to_many(projects => accounts => 'project');

sub _add {
   my ($self, $amount) = @_;
   $self->total($self->total() + $amount);
   $self->update();
   return $self;
} ## end sub add_amount

sub as_hash {
   my $self = shift;
   my %cols = $self->get_columns();
   return %cols if wantarray();
   return \%cols;
} ## end sub as_hash

sub TO_JSON { return scalar shift->as_hash() }

1;
