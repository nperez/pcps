package POE::Component::PubSub::Status;
use warnings;
use strict;

use base 'Exporter';

use constant
{
    'PCPS_NOT_PUBLISHED' => 0,
    'PCPS_NOT_OWNED' => 1,
    'PCPS_NO_SUBSCRIBERS' => 2,
    'PCPS_INVALID_EVENT' => 3,
    'PCPS_EVENT_EXISTS' => 4,
};

our $VERSION = '0.01';

our @EXPORT = 
    qw/ 
        &PCPS_NOT_PUBLISHED
        &PCPS_NOT_OWNED
        &PCPS_NO_SUBSCRIBERS
        &PCPS_INVALID_EVENT
        &PCPS_EVENT_EXISTS
    /;

1;
