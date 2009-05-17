#!perl -T

use Test::More tests => 3;

BEGIN {
    use_ok( 'POE::Component::PubSub::Types' );
	use_ok( 'POE::Component::PubSub::Event' );
    use_ok( 'POE::Component::PubSub' );

}

diag( "Testing POE::Component::PubSub $POE::Component::PubSub::VERSION, Perl $], $^X" );
