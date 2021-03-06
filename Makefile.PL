use strict;
use warnings;
use inc::Module::Install;
use Module::Install::AuthorRequires;
use Module::Install::ExtraTests;
use 5.008001;

check_conflicts();

name 'Class-MOP';
perl_version '5.008001';
all_from 'lib/Class/MOP.pm';
license 'perl';

require Config;
my $ccflags = ( $Config::Config{ccflags} || '' ) . ' -I.';

if ( -d '.git' || $ENV{MAINTAINER_MODE} ) {
    $ccflags .= ' -Wall -Wdeclaration-after-statement';
}

requires 'Carp';
requires 'Data::OptList';
requires 'Devel::GlobalDestruction';
requires 'List::MoreUtils'             => '0.12';
requires 'MRO::Compat'                 => '0.05';
requires 'Package::DeprecationManager' => '0.10';
requires 'Package::Stash'              => '0.13';
requires 'Scalar::Util'                => '1.18';
requires 'Sub::Name'                   => '0.04';
requires 'Try::Tiny'                   => '0.02';
requires 'Task::Weaken';

test_requires 'File::Spec';
test_requires 'Test::More'     => '0.88';
test_requires 'Test::Fatal'    => '0.001';
test_requires 'Test::Requires' => '0.05';

author_requires 'Algorithm::C3';
author_requires 'Module::Info';
author_requires 'Test::LeakTrace';
author_requires 'Test::NoTabs';
author_requires 'Test::Output';
author_requires 'Test::Spelling';

repository 'git://git.moose.perl.org/Class-MOP.git';
add_metadata(x_authority => 'cpan:STEVAN');

extra_tests();

makemaker_args( CCFLAGS => $ccflags );

{
    my (@clean, @OBJECT, %XS);

    for my $xs (<xs/*.xs>) {
        (my $c = $xs) =~ s/\.xs$/.c/i;
        (my $o = $xs) =~ s/\.xs$/\$(OBJ_EXT)/i;

        $XS{$xs} = $c;
        push @OBJECT, $o;
        push @clean, $o;
    }

    for my $c (<*.c>) {
        (my $o = $c) =~ s/\.c$/\$(OBJ_EXT)/i;
        push @OBJECT, $o;
        push @clean, $o;
    }

    makemaker_args(
        clean  => { FILES => join(q{ }, @clean) },
        OBJECT => join (q{ }, @OBJECT),
        XS     => \%XS,
    );
}

postamble(<<'EOM');
$(OBJECT) : mop.h
EOM

WriteAll();

# Use the cpan-smolder-stable script in the Moose svn root to figure
# out what on CPAN will break with the latest Moose, then update this
# before a release.
sub check_conflicts {
    my %conflicts = (
        'Moose'                         => '1.14',
        'namespace::autoclean'          => '0.08',
    );

    my $found = 0;
    for my $mod ( sort keys %conflicts ) {
        eval "require $mod";
        next if $@;

        my $installed = $mod->VERSION();
        if ( $installed le $conflicts{$mod} ) {

            print <<"EOF";

***
    This version of Class::MOP conflicts with the version of
    $mod ($installed) you have installed.

    You will need to upgrade $mod after installing
    this version of Class::MOP.
***

EOF

            $found = 1;
        }
    }

    return unless $found;

    # More or less copied from Module::Build
    return if $ENV{PERL_MM_USE_DEFAULT};
    return unless -t STDIN && ( -t STDOUT || !( -f STDOUT || -c STDOUT ) );

    sleep 4;
}

package MY;

use Config;

sub const_cccmd {
    my $ret = shift->SUPER::const_cccmd(@_);
    return q{} unless $ret;

    if ($Config{cc} =~ /^cl\b/i) {
        warn 'you are using MSVC... my condolences.';
        $ret .= ' /Fo$@';
    }
    else {
        $ret .= ' -o $@';
    }

    return $ret;
}
