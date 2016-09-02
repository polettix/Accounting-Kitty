package Accounting::Kitty::Result::TransferBase;

use utf8;
use strict;
use warnings;
{ our $VERSION = '0.001'; }

use Scalar::Util qw< looks_like_number >;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime');

__PACKAGE__->table('transfer');

__PACKAGE__->add_columns(
   id => {
      data_type         => 'integer',
      is_auto_increment => 1,
      is_nullable       => 0
   },
   src_id => {
      data_type      => 'integer',
      is_foreign_key => 1,
      is_nullable    => 1
   },
   dst_id => {
      data_type      => 'integer',
      is_foreign_key => 1,
      is_nullable    => 1
   },
   amount => {data_type => 'integer', is_nullable => 1},
   date_  => {
      data_type        => 'text',
      is_nullable      => 1,
      inflate_datetime => 1,
      accessor         => 'date'
   },
   title       => {data_type => 'text', is_nullable => 1},
   description => {data_type => 'text', is_nullable => 1},
   parent_id   => {
      data_type      => 'integer',
      is_foreign_key => 1,
      is_nullable    => 1
   },
   is_deleted => {data_type => 'integer', is_nullable => 1},
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
   dst => 'Accounting::Kitty::Result::Account',
   {id => 'dst_id'},
   {
      is_deferrable => 1,
      join_type     => 'LEFT',
      on_delete     => 'CASCADE',
      on_update     => 'CASCADE',
   },
);

__PACKAGE__->belongs_to(
   src => 'Accounting::Kitty::Result::Account',
   {id => 'src_id'},
   {
      is_deferrable => 1,
      join_type     => 'LEFT',
      on_delete     => 'CASCADE',
      on_update     => 'CASCADE',
   },
);

__PACKAGE__->belongs_to(
   parent => 'Accounting::Kitty::Result::Transfer',
   {id => 'parent_id'},
   {
      is_deferrable => 1,
      join_type     => 'LEFT',
      on_delete     => 'CASCADE',
      on_update     => 'CASCADE',
   },
);

__PACKAGE__->has_many(
   children => 'Accounting::Kitty::Result::Transfer',
   {'foreign.parent_id' => 'self.id'},
   {cascade_copy        => 0, cascade_delete => 0},
);

sub _mark_deleted {
   my $self = shift;
   $self->result_source()->schema()->txn_do(
      sub {

         # get rid of any descendant, this will propagate properly
         $_->_mark_deleted() for $self->proper_children();

         # roll this transfer back
         my $amount = $self->amount();
         $self->src()->add_amount($amount);
         $self->dst()->subtract_amount($amount);

         # mark as deleted, keep this forever (or until purge)
         $self->is_deleted(1);
         $self->update();

      },
   );
   return;
} ## end sub _mark_deleted

sub mark_deleted {
   my $self = shift;

   # if there's a parent, all siblings have to be deleted as well,
   my $parent = $self->proper_parent()
     or return $self->_mark_deleted();    # or just operate on this one

   # there's a parent, delete all children of parent, this included
   $_->_mark_deleted() for $parent->proper_children();

   return;
} ## end sub mark_deleted

sub proper_children {
   my $self = shift;
   my $id   = $self->id();
   return
     grep { (!$_->is_deleted()) && ($_->id() != $id) } $self->children();
} ## end sub proper_children

sub proper_parent {
   my $self   = shift;
   my $parent = $self->parent();
   return $parent if $parent->id() != $self->id();
   return undef;
} ## end sub proper_parent

sub attributable {
   my $self = shift;
   return !$self->proper_parent();
}

sub attributed {
   my $self = shift;
   return scalar $self->proper_children();
}

sub as_hash {
   my $self   = shift;
   my %retval = $self->get_columns();
   delete $retval{date_};
   $retval{date} = $self->date()->clone();
   return %retval if wantarray();
   return \%retval;
} ## end sub as_hash

1;
