#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'POE::Component::PubSub' );
}

diag( "Testing POE::Component::PubSub $POE::Component::PubSub::VERSION, Perl $], $^X" );
