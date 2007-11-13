
package Class::MOP::Instance;

use strict;
use warnings;

use Scalar::Util 'weaken', 'blessed';

our $VERSION   = '0.03';
our $AUTHORITY = 'cpan:STEVAN';

sub meta {
    require Class::MOP::Class;
    Class::MOP::Class->initialize(blessed($_[0]) || $_[0]);
}

sub new {
    my ($class, $meta, @attrs) = @_;
    my @slots = map { $_->slots } @attrs;
    my $instance = bless {
        # NOTE:
        # I am not sure that it makes
        # sense to pass in the meta
        # The ideal would be to just
        # pass in the class name, but
        # that is placing too much of
        # an assumption on bless(),
        # which is *probably* a safe
        # assumption,.. but you can
        # never tell <:)
        '$!meta'  => $meta,
        '@!slots' => { map { $_ => undef } @slots },
    } => $class;

    weaken($instance->{'$!meta'});

    return $instance;
}

sub associated_metaclass { (shift)->{'$!meta'} }

sub create_instance {
    my $self = shift;
    $self->bless_instance_structure({});
}

sub bless_instance_structure {
    my ($self, $instance_structure) = @_;
    bless $instance_structure, $self->associated_metaclass->name;
}

sub clone_instance {
    my ($self, $instance) = @_;
    $self->bless_instance_structure({ %$instance });
}

# operations on meta instance

sub get_all_slots {
    my $self = shift;
    return keys %{$self->{'@!slots'}};
}

sub is_valid_slot {
    my ($self, $slot_name) = @_;
    exists $self->{'@!slots'}->{$slot_name} ? 1 : 0;
}

# operations on created instances

sub get_slot_value {
    my ($self, $instance, $slot_name) = @_;
    $self->is_slot_initialized($instance, $slot_name) ? $instance->{$slot_name} : undef;
}

sub set_slot_value {
    my ($self, $instance, $slot_name, $value) = @_;
    $instance->{$slot_name} = $value;
}

sub initialize_slot {
    my ($self, $instance, $slot_name) = @_;
    #$self->set_slot_value($instance, $slot_name, undef);
}

sub deinitialize_slot {
    my ( $self, $instance, $slot_name ) = @_;
    delete $instance->{$slot_name};
}

sub initialize_all_slots {
    my ($self, $instance) = @_;
    foreach my $slot_name ($self->get_all_slots) {
        $self->initialize_slot($instance, $slot_name);
    }
}

sub deinitialize_all_slots {
    my ($self, $instance) = @_;
    foreach my $slot_name ($self->get_all_slots) {
        $self->deinitialize_slot($instance, $slot_name);
    }
}

sub is_slot_initialized {
    my ($self, $instance, $slot_name, $value) = @_;
    exists $instance->{$slot_name} ? 1 : 0;
}

sub weaken_slot_value {
        my ($self, $instance, $slot_name) = @_;
        weaken $instance->{$slot_name};
}

sub strengthen_slot_value {
        my ($self, $instance, $slot_name) = @_;
        $self->set_slot_value($instance, $slot_name, $self->get_slot_value($instance, $slot_name));
}

# inlinable operation snippets

sub is_inlinable { 1 }

sub inline_create_instance {
    my ($self, $class_variable) = @_;
    'bless {} => ' . $class_variable;
}

sub inline_slot_access {
    my ($self, $instance, $slot_name) = @_;
    sprintf "%s->{%s}", $instance, $slot_name;
}

sub inline_get_slot_value {
    my ($self, $instance, $slot_name) = @_;
    'exists ' . $self->inline_slot_access($instance, $slot_name) .
    ' ? ' . $self->inline_slot_access($instance, $slot_name) . ' : undef'
}

sub inline_set_slot_value {
    my ($self, $instance, $slot_name, $value) = @_;
    $self->inline_slot_access($instance, $slot_name) . " = $value",
}

sub inline_initialize_slot {
    my ($self, $instance, $slot_name) = @_;
    $self->inline_set_slot_value($instance, $slot_name, 'undef'),
}

sub inline_deinitialize_slot {
    my ($self, $instance, $slot_name) = @_;
    "delete " . $self->inline_slot_access($instance, $slot_name);
}
sub inline_is_slot_initialized {
    my ($self, $instance, $slot_name) = @_;
    "exists " . $self->inline_slot_access($instance, $slot_name) . " ? 1 : 0";
}

sub inline_weaken_slot_value {
    my ($self, $instance, $slot_name) = @_;
    sprintf "Scalar::Util::weaken( %s )", $self->inline_slot_access($instance, $slot_name);
}

sub inline_strengthen_slot_value {
    my ($self, $instance, $slot_name) = @_;
    $self->inline_set_slot_value($instance, $slot_name, $self->inline_slot_access($instance, $slot_name));
}

1;

__END__

=pod

=head1 NAME

Class::MOP::Instance - Instance Meta Object

=head1 SYNOPSIS

  # for the most part, this protocol is internal
  # and not for public usage, but this how one
  # might use it

  package Foo;

  use strict;
  use warnings;
  use metaclass (
      ':instance_metaclass'  => 'ArrayBasedStorage::Instance',
  );

  # now Foo->new produces blessed ARRAY ref based objects

=head1 DESCRIPTION

This is a sub-protocol which governs instance creation
and access to the slots of the instance structure.

This may seem like over-abstraction, but by abstracting
this process into a sub-protocol we make it possible to
easily switch the details of how an object's instance is
stored with minimal impact. In most cases just subclassing
this class will be all you need to do (see the examples;
F<examples/ArrayBasedStorage.pod> and
F<examples/InsideOutClass.pod> for details).

=head1 METHODS

=over 4

=item B<new ($meta, @attrs)>

Creates a new instance meta-object and gathers all the slots from
the list of C<@attrs> given.

=item B<meta>

This will return a B<Class::MOP::Class> instance which is related
to this class.

=back

=head2 Creation of Instances

=over 4

=item B<create_instance>

This creates the appropriate structure needed for the instance and
then calls C<bless_instance_structure> to bless it into the class.

=item B<bless_instance_structure ($instance_structure)>

This does just exactly what it says it does.

=item B<clone_instance ($instance_structure)>

=back

=head2 Instrospection

NOTE: There might be more methods added to this part of the API,
we will add then when we need them basically.

=over 4

=item B<associated_metaclass>

=item B<get_all_slots>

This will return the current list of slots based on what was
given to this object in C<new>.

=item B<is_valid_slot ($slot_name)>

=back

=head2 Operations on Instance Structures

An important distinction of this sub-protocol is that the
instance meta-object is a different entity from the actual
instance it creates. For this reason, any actions on slots
require that the C<$instance_structure> is passed into them.

=over 4

=item B<get_slot_value ($instance_structure, $slot_name)>

=item B<set_slot_value ($instance_structure, $slot_name, $value)>

=item B<initialize_slot ($instance_structure, $slot_name)>

=item B<deinitialize_slot ($instance_structure, $slot_name)>

=item B<initialize_all_slots ($instance_structure)>

=item B<deinitialize_all_slots ($instance_structure)>

=item B<is_slot_initialized ($instance_structure, $slot_name)>

=item B<weaken_slot_value ($instance_structure, $slot_name)>

=item B<strengthen_slot_value ($instance_structure, $slot_name)>

=back

=head2 Inlineable Instance Operations

This part of the API is currently un-used. It is there for use
in future experiments in class finailization mostly. Best to
ignore this for now.

=over 4

=item B<is_inlinable>

Each meta-instance should override this method to tell Class::MOP if it's
possible to inline the slot access.

This is currently only used by Class::MOP::Class::Immutable when performing
optimizations.

=item B<inline_create_instance>

=item B<inline_slot_access ($instance_structure, $slot_name)>

=item B<inline_get_slot_value ($instance_structure, $slot_name)>

=item B<inline_set_slot_value ($instance_structure, $slot_name, $value)>

=item B<inline_initialize_slot ($instance_structure, $slot_name)>

=item B<inline_deinitialize_slot ($instance_structure, $slot_name)>

=item B<inline_is_slot_initialized ($instance_structure, $slot_name)>

=item B<inline_weaken_slot_value ($instance_structure, $slot_name)>

=item B<inline_strengthen_slot_value ($instance_structure, $slot_name)>

=back

=head1 AUTHORS

Yuval Kogman E<lt>nothingmuch@woobling.comE<gt>

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2007 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

