#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Test::Requires {
    'Test::Pod::Coverage' => '1.04', # skip all if not installed
};

# This is a stripped down version of all_pod_coverage_ok which lets us
# vary the trustme parameter per module.
my @modules = all_modules();
plan tests => scalar @modules;

my %trustme = (
    'Class::MOP' => [
        'DEBUG_NO_META',
        'HAVE_ISAREV',
        'subname',
        'in_global_destruction',
    ],
    'Class::MOP::Attribute' => ['process_accessors'],
    'Class::MOP::Class'     => [
        # deprecated
        'alias_method',
        'compute_all_applicable_attributes',
        'compute_all_applicable_methods',

        # unfinished feature
        'add_dependent_meta_instance',
        'add_meta_instance_dependencies',
        'invalidate_meta_instance',
        'invalidate_meta_instances',
        'remove_dependent_meta_instance',
        'remove_meta_instance_dependencies',
        'update_meta_instance_dependencies',

        # effectively internal
        'check_metaclass_compatibility',
        'clone_instance',
        'construct_class_instance',
        'construct_instance',
        'create_meta_instance',
        'reset_package_cache_flag',
        'update_package_cache_flag',
        'reinitialize',

        # doc'd with rebless_instance
        'rebless_instance_away',

        # deprecated
        'get_attribute_map',
    ],
    'Class::MOP::Class::Immutable::Trait'             => ['.+'],
    'Class::MOP::Class::Immutable::Class::MOP::Class' => ['.+'],
    'Class::MOP::Deprecated'                          => ['.+'],
    'Class::MOP::Instance'                            => [
        qw( BUILDARGS
            bless_instance_structure
            is_dependent_on_superclasses ),
    ],
    'Class::MOP::Instance' => [
        qw( BUILDARGS
            bless_instance_structure
            is_dependent_on_superclasses ),
    ],
    'Class::MOP::Method::Accessor' => [
        qw( generate_accessor_method
            generate_accessor_method_inline
            generate_clearer_method
            generate_clearer_method_inline
            generate_predicate_method
            generate_predicate_method_inline
            generate_reader_method
            generate_reader_method_inline
            generate_writer_method
            generate_writer_method_inline
            initialize_body
            )
    ],
    'Class::MOP::Method::Constructor' => [
        qw( attributes
            generate_constructor_method
            generate_constructor_method_inline
            initialize_body
            meta_instance
            options
            )
    ],
    'Class::MOP::Method::Generated' => [
        qw( new
            definition_context
            is_inline
            initialize_body
            )
    ],
    'Class::MOP::MiniTrait' => ['.+'],
    'Class::MOP::Mixin::AttributeCore' => ['.+'],
    'Class::MOP::Mixin::HasAttributes' => ['.+'],
    'Class::MOP::Mixin::HasMethods'    => ['.+'],
    'Class::MOP::Module'               => ['create'],
    'Class::MOP::Package' => [ 'get_method_map', 'wrap_method_body' ],
);

for my $module ( sort @modules ) {
    my $trustme = [];
    if ( $trustme{$module} ) {
        my $methods = join '|', @{ $trustme{$module} };
        $trustme = [qr/^(?:$methods)$/];
    }

    pod_coverage_ok(
        $module, { trustme => $trustme },
        "Pod coverage for $module"
    );
}
