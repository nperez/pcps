package POE::Component::PubSub::Status;
use warnings;
use strict;

use base 'Exporter';

use constant
{
    'PCPS_OK' => 0,
    'PCPS_NOT_PUBLISHED' => 1,
    'PCPS_NOT_OWNED' => 2,
    'PCPS_NO_SUBSCRIBERS' => 3,
    'PCPS_INVALID_EVENT' => 4,
    'PCPS_EVENT_EXISTS' => 5,
};

our $VERSION = '0.01';

our @EXPORT = 
    qw/ 
        &PCPS_OK
        &PCPS_NOT_PUBLISHED
        &PCPS_NOT_OWNED
        &PCPS_NO_SUBSCRIBERS
        &PCPS_INVALID_EVENT
        &PCPS_EVENT_EXISTS
    /;

1;
