package POE::Component::PubSub::Types;
use warnings;
use strict;

use base('Exporter');

our $VERSION = '3.00';

use constant
{
    'PUBLISH_INPUT'     => 0,
    'PUBLISH_OUTPUT'    => 1,
};

our @EXPORT = qw/ PUBLISH_INPUT PUBLISH_OUTPUT /;

1;

