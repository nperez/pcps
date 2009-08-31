package POEx::PubSub::Types;

#ABSTRACT: Exported Types for use within POEx::PubSub

=head1 DESCRIPTION

This modules exports the needed subtypes, coercions, and constants for PubSub
and is based on Sub::Exporter, so see that module for options on importing.

=cut

use Moose;
use MooseX::Types -declare => [ 'PublishType', 'Subscriber' ];
use MooseX::Types::Moose('Int', 'Str');
use MooseX::Types::Structured('Dict');
use POEx::Types(':all');

=head1 CONSTANTS

=head2 PUBLISH_OUTPUT

This indicates the Event is an output event

=head2 PUBLISH_INPUT

This indicates the Event is an input event

=cut

use constant PUBLISH_OUTPUT => 2;
use constant PUBLISH_INPUT  => -2;

use Sub::Exporter -setup => 
{ 
    exports => 
    [ 
        qw/ 
            PublishType 
            Subscriber 
            PUBLISH_INPUT 
            PUBLISH_OUTPUT 
        /
    ] 
};

=head1 TYPES

=head2 PublishType

The publish type constraint applied to Events. Can either be PUBLISH_INPUT or 
PUBLISH_OUTPUT

=cut

subtype PublishType,
    as Int,
    where { $_ == -2 || $_ == 2 },
    message { 'PublishType is not PublishInput or PublishOutput' };

=head2 Subscriber

When manipulating subscribers in an Event, expect to receive a well formed hash
with the keys 'session' and 'event' corresponding to the subscribers SessionID
and their event handler, respectively

=cut

subtype Subscriber,
    as Dict[session => SessionID, event => Str];

1;

__END__
