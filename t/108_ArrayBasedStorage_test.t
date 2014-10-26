#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 65;
use File::Spec;

BEGIN { 
    use_ok('Class::MOP');    
    require_ok(File::Spec->catdir('examples', 'ArrayBasedStorage.pod'));
}

{
    package Foo;
    
    use strict;
    use warnings;    
    use metaclass (
        ':instance_metaclass'  => 'ArrayBasedStorage::Instance',
    );
    
    Foo->meta->add_attribute('foo' => (
        accessor  => 'foo',
        predicate => 'has_foo',
    ));
    
    Foo->meta->add_attribute('bar' => (
        reader  => 'get_bar',
        writer  => 'set_bar',
        default => 'FOO is BAR'            
    ));
    
    sub new  {
        my $class = shift;
        $class->meta->new_object(@_);
    }
    
    package Bar;
    
    use strict;
    use warnings;
    
    use base 'Foo';
    
    Bar->meta->add_attribute('baz' => (
        accessor  => 'baz',
        predicate => 'has_baz',
    ));   
    
    package Baz;
    
    use strict;
    use warnings;
    use metaclass (        
        ':instance_metaclass'  => 'ArrayBasedStorage::Instance',
    );
    
    Baz->meta->add_attribute('bling' => (
        accessor  => 'bling',
        default   => 'Baz::bling'
    ));     
    
    package Bar::Baz;
    
    use strict;
    use warnings;
    
    use base 'Bar', 'Baz'; 
}

my $foo = Foo->new();
isa_ok($foo, 'Foo');

can_ok($foo, 'foo');
can_ok($foo, 'has_foo');
can_ok($foo, 'get_bar');
can_ok($foo, 'set_bar');

ok(!$foo->has_foo, '... Foo::foo is not defined yet');
is($foo->foo(), undef, '... Foo::foo is not defined yet');
is($foo->get_bar(), 'FOO is BAR', '... Foo::bar has been initialized');

$foo->foo('This is Foo');

ok($foo->has_foo, '... Foo::foo is defined now');
is($foo->foo(), 'This is Foo', '... Foo::foo == "This is Foo"');

$foo->set_bar(42);
is($foo->get_bar(), 42, '... Foo::bar == 42');

my $foo2 = Foo->new();
isa_ok($foo2, 'Foo');

ok(!$foo2->has_foo, '... Foo2::foo is not defined yet');
is($foo2->foo(), undef, '... Foo2::foo is not defined yet');
is($foo2->get_bar(), 'FOO is BAR', '... Foo2::bar has been initialized');

$foo2->set_bar('DONT PANIC');
is($foo2->get_bar(), 'DONT PANIC', '... Foo2::bar == DONT PANIC');

is($foo->get_bar(), 42, '... Foo::bar == 42');

# now Bar ...

my $bar = Bar->new();
isa_ok($bar, 'Bar');
isa_ok($bar, 'Foo');

can_ok($bar, 'foo');
can_ok($bar, 'has_foo');
can_ok($bar, 'get_bar');
can_ok($bar, 'set_bar');
can_ok($bar, 'baz');
can_ok($bar, 'has_baz');

ok(!$bar->has_foo, '... Bar::foo is not defined yet');
is($bar->foo(), undef, '... Bar::foo is not defined yet');
is($bar->get_bar(), 'FOO is BAR', '... Bar::bar has been initialized');
ok(!$bar->has_baz, '... Bar::baz is not defined yet');
is($bar->baz(), undef, '... Bar::baz is not defined yet');

$bar->foo('This is Bar::foo');

ok($bar->has_foo, '... Bar::foo is defined now');
is($bar->foo(), 'This is Bar::foo', '... Bar::foo == "This is Bar"');
is($bar->get_bar(), 'FOO is BAR', '... Bar::bar has been initialized');

$bar->baz('This is Bar::baz');

ok($bar->has_baz, '... Bar::baz is defined now');
is($bar->baz(), 'This is Bar::baz', '... Bar::foo == "This is Bar"');
is($bar->foo(), 'This is Bar::foo', '... Bar::foo == "This is Bar"');
is($bar->get_bar(), 'FOO is BAR', '... Bar::bar has been initialized');

# now Baz ...

my $baz = Bar::Baz->new();
isa_ok($baz, 'Bar::Baz');
isa_ok($baz, 'Bar');
isa_ok($baz, 'Foo');
isa_ok($baz, 'Baz');

can_ok($baz, 'foo');
can_ok($baz, 'has_foo');
can_ok($baz, 'get_bar');
can_ok($baz, 'set_bar');
can_ok($baz, 'baz');
can_ok($baz, 'has_baz');
can_ok($baz, 'bling');

is($baz->get_bar(), 'FOO is BAR', '... Bar::Baz::bar has been initialized');
is($baz->bling(), 'Baz::bling', '... Bar::Baz::bling has been initialized');

ok(!$baz->has_foo, '... Bar::Baz::foo is not defined yet');
is($baz->foo(), undef, '... Bar::Baz::foo is not defined yet');
ok(!$baz->has_baz, '... Bar::Baz::baz is not defined yet');
is($baz->baz(), undef, '... Bar::Baz::baz is not defined yet');

$baz->foo('This is Bar::Baz::foo');

ok($baz->has_foo, '... Bar::Baz::foo is defined now');
is($baz->foo(), 'This is Bar::Baz::foo', '... Bar::Baz::foo == "This is Bar"');
is($baz->get_bar(), 'FOO is BAR', '... Bar::Baz::bar has been initialized');
is($baz->bling(), 'Baz::bling', '... Bar::Baz::bling has been initialized');

$baz->baz('This is Bar::Baz::baz');

ok($baz->has_baz, '... Bar::Baz::baz is defined now');
is($baz->baz(), 'This is Bar::Baz::baz', '... Bar::Baz::foo == "This is Bar"');
is($baz->foo(), 'This is Bar::Baz::foo', '... Bar::Baz::foo == "This is Bar"');
is($baz->get_bar(), 'FOO is BAR', '... Bar::Baz::bar has been initialized');
is($baz->bling(), 'Baz::bling', '... Bar::Baz::bling has been initialized');


