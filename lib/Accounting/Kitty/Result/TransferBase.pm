use utf8;

package Accounting::Kitty::Result::Transfer;
use Scalar::Util qw< looks_like_number >;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Accounting::Kitty::Result::Transfer

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<transfer>

=cut

__PACKAGE__->table("transfer");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 src

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 dst

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 amount

  data_type: 'integer'
  is_nullable: 1

=head2 tdate

  data_type: 'text'
  is_nullable: 1

=head2 title

  data_type: 'text'
  is_nullable: 1

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 parent

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 deleted

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
   "id",
   {data_type => "integer", is_auto_increment => 1, is_nullable => 0},
   "src",
   {data_type => "integer", is_foreign_key => 1, is_nullable => 1},
   "dst",
   {data_type => "integer", is_foreign_key => 1, is_nullable => 1},
   "amount",
   {data_type => "integer", is_nullable => 1},
   "tdate",
   {
      data_type        => "text",
      is_nullable      => 1,
      inflate_datetime => 1,
      accessor         => 'date'
   },
   "title",
   {data_type => "text", is_nullable => 1},
   "description",
   {data_type => "text", is_nullable => 1},
   "parent",
   {data_type => "integer", is_foreign_key => 1, is_nullable => 1},
   "deleted",
   {data_type => "integer", is_nullable => 1},
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 dst

Type: belongs_to

Related object: L<Accounting::Kitty::Result::Account>

=cut

__PACKAGE__->belongs_to(
   "dst",
   "Accounting::Kitty::Result::Account",
   {id => "dst"},
   {
      is_deferrable => 1,
      join_type     => "LEFT",
      on_delete     => "CASCADE",
      on_update     => "CASCADE",
   },
);

=head2 parent

Type: belongs_to

Related object: L<Accounting::Kitty::Result::Transfer>

=cut

__PACKAGE__->belongs_to(
   "parent",
   "Accounting::Kitty::Result::Transfer",
   {id => "parent"},
   {
      is_deferrable => 1,
      join_type     => "LEFT",
      on_delete     => "CASCADE",
      on_update     => "CASCADE",
   },
);

=head2 src

Type: belongs_to

Related object: L<Accounting::Kitty::Result::Account>

=cut

__PACKAGE__->belongs_to(
   "src",
   "Accounting::Kitty::Result::Account",
   {id => "src"},
   {
      is_deferrable => 1,
      join_type     => "LEFT",
      on_delete     => "CASCADE",
      on_update     => "CASCADE",
   },
);

=head2 tags

Type: has_many

Related object: L<Accounting::Kitty::Result::Tag>

=cut

__PACKAGE__->has_many(
   "tags",
   "Accounting::Kitty::Result::Tag",
   {"foreign.transfer_id" => "self.id"},
   {cascade_copy          => 0, cascade_delete => 0},
);

=head2 children

Type: has_many

Related object: L<Accounting::Kitty::Result::Transfer>

=cut

__PACKAGE__->has_many(
   "children",
   "Accounting::Kitty::Result::Transfer",
   {"foreign.parent" => "self.id"},
   {cascade_copy     => 0, cascade_delete => 0},
);

# Created by DBIx::Class::Schema::Loader v0.07022 @ 2013-07-27 14:31:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:h2k+VvHvSFGp2v2kP9bj6g

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
         $self->deleted(1);
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
   return grep { (!$_->deleted()) && ($_->id() != $id) } $self->children();
}

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
   delete $retval{tdate};
   $retval{date} = $self->date()->clone();
   return %retval if wantarray();
   return \%retval;
} ## end sub as_hash

1;
