
package Class::MOP::Method;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'weaken';

our $VERSION   = '0.71_02';
$VERSION = eval $VERSION;
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Object';

# NOTE:
# if poked in the right way,
# they should act like CODE refs.
use overload '&{}' => sub { $_[0]->body }, fallback => 1;

our $UPGRADE_ERROR_TEXT = q{
---------------------------------------------------------
NOTE: this error is likely not an error, but a regression
caused by the latest upgrade to Moose/Class::MOP. Consider
upgrading any MooseX::* modules to their latest versions
before spending too much time chasing this one down.
---------------------------------------------------------
};

# construction

sub wrap {
    my ( $class, @args ) = @_;

    unshift @args, 'body' if @args % 2 == 1;

    my %params = @args;
    my $code = $params{body};

    ('CODE' eq ref($code))
        || confess "You must supply a CODE reference to bless, not (" . ($code || 'undef') . ")";

    ($params{package_name} && $params{name})
        || confess "You must supply the package_name and name parameters $UPGRADE_ERROR_TEXT";

    my $self = $class->_new(\%params);

    weaken($self->{associated_metaclass}) if $self->{associated_metaclass};

    return $self;
}

sub _new {
    my $class = shift;
    my $params = @_ == 1 ? $_[0] : {@_};

    my $self = bless {
        'body'                 => $params->{body},
        'associated_metaclass' => $params->{associated_metaclass},
        'package_name'         => $params->{package_name},
        'name'                 => $params->{name},
    } => $class;
}

## accessors

sub body { (shift)->{'body'} }

sub associated_metaclass { shift->{'associated_metaclass'} }

sub attach_to_class {
    my ( $self, $class ) = @_;
    $self->{associated_metaclass} = $class;
    weaken($self->{associated_metaclass});
}

sub detach_from_class {
    my $self = shift;
    delete $self->{associated_metaclass};
}

sub package_name { (shift)->{'package_name'} }

sub name { (shift)->{'name'} }

sub fully_qualified_name {
    my $self = shift;
    $self->package_name . '::' . $self->name;
}

sub original_method { (shift)->{'original_method'} }

sub _set_original_method { $_[0]->{'original_method'} = $_[1] }

# It's possible that this could cause a loop if there is a circular
# reference in here. That shouldn't ever happen in normal
# circumstances, since original method only gets set when clone is
# called. We _could_ check for such a loop, but it'd involve some sort
# of package-lexical variable, and wouldn't be terribly subclassable.
sub original_package_name {
    my $self = shift;

    $self->original_method
        ? $self->original_method->original_package_name
        : $self->package_name;
}

sub original_name {
    my $self = shift;

    $self->original_method
        ? $self->original_method->original_name
        : $self->name;
}

sub original_fully_qualified_name {
    my $self = shift;

    $self->original_method
        ? $self->original_method->original_fully_qualified_name
        : $self->fully_qualified_name;
}

sub execute {
    my $self = shift;
    $self->body->(@_);
}

# NOTE:
# the Class::MOP bootstrap
# will create this for us
# - SL
# sub clone { ... }

1;

__END__

=pod

=head1 NAME

Class::MOP::Method - Method Meta Object

=head1 DESCRIPTION

The Method Protocol is very small, since methods in Perl 5 are just
subroutines within the particular package. We provide a very basic
introspection interface.

=head1 METHODS

=head2 Introspection

=over 4

=item B<meta>

This will return a B<Class::MOP::Class> instance which is related
to this class.

=back

=head2 Construction

=over 4

=item B<wrap ($code, %params)>

This is the basic constructor, it returns a B<Class::MOP::Method>
instance which wraps the given C<$code> reference. You can also
set the C<package_name> and C<name> attributes using the C<%params>.
If these are not set, then thier accessors will attempt to figure
it out using the C<Class::MOP::get_code_info> function.

=item B<clone (%params)>

This will make a copy of the object, allowing you to override
any values by stuffing them in C<%params>.

=back

=head2 Informational

=over 4

=item B<body>

This returns the actual CODE reference of the particular instance.

=item B<name>

This returns the name of the CODE reference.

=item B<associated_metaclass>

The metaclass of the method

=item B<package_name>

This returns the package name that the CODE reference is attached to.

=item B<fully_qualified_name>

This returns the fully qualified name of the CODE reference.

=item B<original_method>

If this method object was created as a clone of some other method
object, this returns the object that was cloned.

=item B<original_name>

This returns the original name of the CODE reference, wherever it was
first defined.

If this method is a clone of a clone (of a clone, etc.), this method
returns the name from the I<first> method in the chain of clones.

=item B<original_package_name>

This returns the original package name that the CODE reference is
attached to, wherever it was first defined.

If this method is a clone of a clone (of a clone, etc.), this method
returns the package name from the I<first> method in the chain of
clones.

=item B<original_fully_qualified_name>

This returns the original fully qualified name of the CODE reference,
wherever it was first defined.

If this method is a clone of a clone (of a clone, etc.), this method
returns the fully qualified name from the I<first> method in the chain
of clones.

=back

=head2 Metaclass

=over 4

=item B<attach_to_class>

Sets the associated metaclass

=item B<detach_from_class>

Disassociates the method from the metaclass

=back

=head2 Miscellaneous

=over 4

=item B<execute>

Executes the method. Be sure to pass in the instance, since the
method expects it.

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2008 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

