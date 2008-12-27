use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'POE::Component::PubSub',
    license             => 'gpl',
    dist_author         => 'Nicholas R. Perez <nperez@cpan.org>',
    dist_version_from   => 'lib/POE/Component/PubSub.pm',
    create_readme       => 1,
    build_requires => {
        'Test::More' => 0,
        'POE' => 1.003
    },
    add_to_cleanup      => [ 'POE-Component-PubSub-*' ],
);

$builder->create_build_script();
