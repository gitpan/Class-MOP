
package Class::MOP::Package;

use strict;
use warnings;

use B;
use Scalar::Util 'blessed';
use Carp         'confess';

our $VERSION   = '0.74';
$VERSION = eval $VERSION;
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Object';

# creation ...

sub initialize {
    my ( $class, @args ) = @_;

    unshift @args, "package" if @args % 2;

    my %options = @args;
    my $package_name = $options{package};


    # we hand-construct the class 
    # until we can bootstrap it
    if ( my $meta = Class::MOP::get_metaclass_by_name($package_name) ) {
        return $meta;
    } else {
        my $meta = ( ref $class || $class )->_new({
            'package'   => $package_name,
            %options,
        });

        Class::MOP::store_metaclass_by_name($package_name, $meta);

        return $meta;
    }
}

sub reinitialize {
    my ( $class, @args ) = @_;

    unshift @args, "package" if @args % 2;

    my %options = @args;
    my $package_name = delete $options{package};

    (defined $package_name && $package_name && !blessed($package_name))
        || confess "You must pass a package name and it cannot be blessed";

    Class::MOP::remove_metaclass_by_name($package_name);

    $class->initialize($package_name, %options); # call with first arg form for compat
}

sub _new {
    my $class = shift;
    my $options = @_ == 1 ? $_[0] : {@_};

    # NOTE:
    # because of issues with the Perl API 
    # to the typeglob in some versions, we 
    # need to just always grab a new 
    # reference to the hash in the accessor. 
    # Ideally we could just store a ref and 
    # it would Just Work, but oh well :\
    $options->{namespace} ||= \undef;

    bless $options, $class;
}

# Attributes

# NOTE:
# all these attribute readers will be bootstrapped 
# away in the Class::MOP bootstrap section

sub name      { $_[0]->{'package'} }
sub namespace { 
    # NOTE:
    # because of issues with the Perl API 
    # to the typeglob in some versions, we 
    # need to just always grab a new 
    # reference to the hash here. Ideally 
    # we could just store a ref and it would
    # Just Work, but oh well :\    
    no strict 'refs';    
    \%{$_[0]->{'package'} . '::'} 
}

# utility methods

{
    my %SIGIL_MAP = (
        '$' => 'SCALAR',
        '@' => 'ARRAY',
        '%' => 'HASH',
        '&' => 'CODE',
    );
    
    sub _deconstruct_variable_name {
        my ($self, $variable) = @_;

        (defined $variable)
            || confess "You must pass a variable name";    

        my $sigil = substr($variable, 0, 1, '');

        (defined $sigil)
            || confess "The variable name must include a sigil";    

        (exists $SIGIL_MAP{$sigil})
            || confess "I do not recognize that sigil '$sigil'";    
        
        return ($variable, $sigil, $SIGIL_MAP{$sigil});
    }
}

# Class attributes

# ... these functions have to touch the symbol table itself,.. yuk

sub add_package_symbol {
    my ($self, $variable, $initial_value) = @_;

    my ($name, $sigil, $type) = ref $variable eq 'HASH'
        ? @{$variable}{qw[name sigil type]}
        : $self->_deconstruct_variable_name($variable); 

    my $pkg = $self->{'package'};

    no strict 'refs';
    no warnings 'redefine', 'misc';    
    *{$pkg . '::' . $name} = ref $initial_value ? $initial_value : \$initial_value;      
}

sub remove_package_glob {
    my ($self, $name) = @_;
    no strict 'refs';        
    delete ${$self->name . '::'}{$name};     
}

# ... these functions deal with stuff on the namespace level

sub has_package_symbol {
    my ($self, $variable) = @_;

    my ($name, $sigil, $type) = ref $variable eq 'HASH'
        ? @{$variable}{qw[name sigil type]}
        : $self->_deconstruct_variable_name($variable);
    
    my $namespace = $self->namespace;
    
    return 0 unless exists $namespace->{$name};   
    
    # FIXME:
    # For some really stupid reason 
    # a typeglob will have a default
    # value of \undef in the SCALAR 
    # slot, so we need to work around
    # this. Which of course means that 
    # if you put \undef in your scalar
    # then this is broken.

    if (ref($namespace->{$name}) eq 'SCALAR') {
        return ($type eq 'CODE');
    }
    elsif ($type eq 'SCALAR') {    
        my $val = *{$namespace->{$name}}{$type};
        return defined(${$val});
    }
    else {
        defined(*{$namespace->{$name}}{$type});
    }
}

sub get_package_symbol {
    my ($self, $variable) = @_;    

    my ($name, $sigil, $type) = ref $variable eq 'HASH'
        ? @{$variable}{qw[name sigil type]}
        : $self->_deconstruct_variable_name($variable);

    my $namespace = $self->namespace;

    $self->add_package_symbol($variable)
        unless exists $namespace->{$name};

    if (ref($namespace->{$name}) eq 'SCALAR') {
        if ($type eq 'CODE') {
            no strict 'refs';
            return \&{$self->name.'::'.$name};
        }
        else {
            return undef;
        }
    }
    else {
        return *{$namespace->{$name}}{$type};
    }
}

sub remove_package_symbol {
    my ($self, $variable) = @_;

    my ($name, $sigil, $type) = ref $variable eq 'HASH'
        ? @{$variable}{qw[name sigil type]}
        : $self->_deconstruct_variable_name($variable);

    # FIXME:
    # no doubt this is grossly inefficient and 
    # could be done much easier and faster in XS

    my ($scalar_desc, $array_desc, $hash_desc, $code_desc) = (
        { sigil => '$', type => 'SCALAR', name => $name },
        { sigil => '@', type => 'ARRAY',  name => $name },
        { sigil => '%', type => 'HASH',   name => $name },
        { sigil => '&', type => 'CODE',   name => $name },
    );

    my ($scalar, $array, $hash, $code);
    if ($type eq 'SCALAR') {
        $array  = $self->get_package_symbol($array_desc)  if $self->has_package_symbol($array_desc);
        $hash   = $self->get_package_symbol($hash_desc)   if $self->has_package_symbol($hash_desc);     
        $code   = $self->get_package_symbol($code_desc)   if $self->has_package_symbol($code_desc);     
    }
    elsif ($type eq 'ARRAY') {
        $scalar = $self->get_package_symbol($scalar_desc) if $self->has_package_symbol($scalar_desc);
        $hash   = $self->get_package_symbol($hash_desc)   if $self->has_package_symbol($hash_desc);     
        $code   = $self->get_package_symbol($code_desc)   if $self->has_package_symbol($code_desc);
    }
    elsif ($type eq 'HASH') {
        $scalar = $self->get_package_symbol($scalar_desc) if $self->has_package_symbol($scalar_desc);
        $array  = $self->get_package_symbol($array_desc)  if $self->has_package_symbol($array_desc);        
        $code   = $self->get_package_symbol($code_desc)   if $self->has_package_symbol($code_desc);      
    }
    elsif ($type eq 'CODE') {
        $scalar = $self->get_package_symbol($scalar_desc) if $self->has_package_symbol($scalar_desc);
        $array  = $self->get_package_symbol($array_desc)  if $self->has_package_symbol($array_desc);        
        $hash   = $self->get_package_symbol($hash_desc)   if $self->has_package_symbol($hash_desc);        
    }    
    else {
        confess "This should never ever ever happen";
    }
        
    $self->remove_package_glob($name);
    
    $self->add_package_symbol($scalar_desc => $scalar) if defined $scalar;      
    $self->add_package_symbol($array_desc  => $array)  if defined $array;    
    $self->add_package_symbol($hash_desc   => $hash)   if defined $hash;
    $self->add_package_symbol($code_desc   => $code)   if defined $code;            
}

sub list_all_package_symbols {
    my ($self, $type_filter) = @_;

    my $namespace = $self->namespace;
    return keys %{$namespace} unless defined $type_filter;
    
    # NOTE:
    # or we can filter based on 
    # type (SCALAR|ARRAY|HASH|CODE)
    if ( $type_filter eq 'CODE' ) {
        return grep { 
        (ref($namespace->{$_})
                ? (ref($namespace->{$_}) eq 'SCALAR')
                : (ref(\$namespace->{$_}) eq 'GLOB'
                   && defined(*{$namespace->{$_}}{CODE})));
        } keys %{$namespace};
    } else {
        return grep { *{$namespace->{$_}}{$type_filter} } keys %{$namespace};
    }
}

sub get_all_package_symbols {
    my ($self, $type_filter) = @_;

    die "Cannot call get_all_package_symbols as a class method"
        unless ref $self;

    my $namespace = $self->namespace;

    if (wantarray) {
        warn 'Class::MOP::Package::get_all_package_symbols in list context is deprecated. use scalar context instead.';
    }

    return (wantarray ? %$namespace : $namespace) unless defined $type_filter;

    my %ret;
    # for some reason this nasty impl is orders of magnitude faster than a clean version
    if ( $type_filter eq 'CODE' ) {
        my $pkg;
        no strict 'refs';
        %ret = map {
            (ref($namespace->{$_})
                ? ( $_ => \&{$pkg ||= $self->name . "::$_"} )
                : ( ref \$namespace->{$_} eq 'GLOB' # don't use {CODE} unless it's really a glob to prevent stringification of stubs
                    && (*{$namespace->{$_}}{CODE})  # the extra parents prevent breakage on 5.8.2
                    ? ( $_ => *{$namespace->{$_}}{CODE} )
                    : (do {
                        my $sym = B::svref_2object(\$namespace->{$_});
                        my $svt = ref $sym if $sym;
                        ($sym && ($svt eq 'B::PV' || $svt eq 'B::IV'))
                            ? ($_ => ($pkg ||= $self->name)->can($_))
                            : () }) ) )
        } keys %$namespace;
    } else {
        %ret = map {
            $_ => *{$namespace->{$_}}{$type_filter}
        } grep {
            !ref($namespace->{$_}) && *{$namespace->{$_}}{$type_filter}
        } keys %$namespace;
    }

    return wantarray ? %ret : \%ret;
}

1;

__END__

=pod

=head1 NAME 

Class::MOP::Package - Package Meta Object

=head1 DESCRIPTION

This is an abstraction of a Perl 5 package, it is a superclass of
L<Class::MOP::Class> and provides all of the symbol table 
introspection methods.

=head1 INHERITANCE

B<Class::MOP::Package> is a subclass of L<Class::MOP::Object>

=head1 METHODS

=over 4

=item B<meta>

Returns a metaclass for this package.

=item B<initialize ($package_name)>

This will initialize a Class::MOP::Package instance which represents 
the package of C<$package_name>.

=item B<reinitialize ($package_name, %options)>

This removes the old metaclass, and creates a new one in it's place.
Do B<not> use this unless you really know what you are doing, it could
very easily make a very large mess of your program.

=item B<name>

This is a read-only attribute which returns the package name for the 
given instance.

=item B<namespace>

This returns a HASH reference to the symbol table. The keys of the 
HASH are the symbol names, and the values are typeglob references.

=item B<add_package_symbol ($variable_name, ?$initial_value)>

Given a C<$variable_name>, which must contain a leading sigil, this 
method will create that variable within the package which houses the 
class. It also takes an optional C<$initial_value>, which must be a 
reference of the same type as the sigil of the C<$variable_name> 
implies.

=item B<get_package_symbol ($variable_name)>

This will return a reference to the package variable in 
C<$variable_name>. 

=item B<has_package_symbol ($variable_name)>

Returns true (C<1>) if there is a package variable defined for 
C<$variable_name>, and false (C<0>) otherwise.

=item B<remove_package_symbol ($variable_name)>

This will attempt to remove the package variable at C<$variable_name>.

=item B<remove_package_glob ($glob_name)>

This will attempt to remove the entire typeglob associated with 
C<$glob_name> from the package. 

=item B<list_all_package_symbols (?$type_filter)>

This will list all the glob names associated with the current package. 
By inspecting the globs returned you can discern all the variables in 
the package.

By passing a C<$type_filter>, you can limit the list to only those 
which match the filter (either SCALAR, ARRAY, HASH or CODE).

=item B<get_all_package_symbols (?$type_filter)>

Works exactly like C<list_all_package_symbols> but returns a HASH of 
name => thing mapping instead of just an ARRAY of names.

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2008 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
