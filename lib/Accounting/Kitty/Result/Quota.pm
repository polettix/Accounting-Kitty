package Accounting::Kitty::Result::Quota;

use utf8;
use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime');

__PACKAGE__->table('quota');

__PACKAGE__->add_columns(
   id => {
      data_type         => 'integer',
      is_auto_increment => 1,
      is_nullable       => 0
   },
   name       => {data_type => 'text', is_nullable => 1},
   account_id => {
      data_type      => 'integer',
      is_foreign_key => 1,
      is_nullable    => 1
   },
   weight => {data_type => 'double', is_nullable => 1},
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
   account => 'Accounting::Kitty::Result::Account',
   {id => 'account_id'},
   {
      is_deferrable => 1,
      join_type     => 'LEFT',
      on_delete     => 'CASCADE',
      on_update     => 'CASCADE',
   },
);

# waiting for something better...
sub project { return shift->account()->project(); }

sub as_hash {
   my $self = shift;
   my %hash = $self->get_columns();
   return %hash if wantarray();
   return \%hash;
} ## end sub as_hash

sub TO_JSON { return scalar(shift->as_hash()) }

1;
