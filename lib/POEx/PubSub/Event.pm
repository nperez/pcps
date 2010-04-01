package POEx::PubSub::Event;

#ABSTRACT: An event abstraction for POEx::PubSub

use MooseX::Declare;

class POEx::PubSub::Event
{
    use POEx::PubSub::Types(':all');
    use MooseX::Types::Moose(':all');

=attribute_public name

    is: rw, isa: Str, required: 1

The name of the event.

=cut

    has name =>
    (
        is          => 'rw',
        isa         => Str,
        required    => 1,
    );

=attribute_public subscribers

    traits: Hash, is: rw, isa: HashRef[Subscriber]

subscribers holds all of the subscribers to this event. Subscribers can be accessed via the following methods:

    {
        all_subscribers => 'values',
        has_subscribers => 'count',
        add_subscriber => 'set',
        remove_subscriber => 'delete',
        get_subscriber => 'get',
    }

=cut

    has subscribers =>
    (
        traits      => ['Hash'],
        is          => 'rw', 
        isa         => HashRef[Subscriber], 
        default     => sub { {} },
        lazy        => 1,
        clearer     => 'clear_subscribers',
        handles     =>
        {
            all_subscribers => 'values',
            has_subscribers => 'count',
            add_subscriber => 'set',
            remove_subscriber => 'delete',
            get_subscriber => 'get',
        }
    );

=attribute_public publisher

    is: rw, isa: Str

The event's publisher.

=cut

    has publisher =>
    (
        is          => 'rw',
        isa         => Str,
        predicate   => 'has_publisher',
    );

=attribute_public publishtype

    is: rw, isa => PublishType

The event's publish type. Defaults to +PUBLISH_OUTPUT.

=cut

    has publishtype =>
    (
        is          => 'rw',
        isa         => PublishType,
        default     => +PUBLISH_OUTPUT,
        trigger     => 
        sub
        { 
            my ($self, $type) = @_;
            confess 'Cannot set publishtype to INPUT if there is no publisher' 
                if $type == +PUBLISH_INPUT and not $self->has_publisher;
        }
    );

=attribute_public input

    is: rw, isa: Str

If the publishtype is set to PUBLISH_INPUT, this will indicate the input
handling event that belongs to the publisher

=cut

    has input =>
    (
        is          => 'rw',
        isa         => Str,
        predicate   => 'has_input',
        trigger     => 
        sub
        {
            my ($self) = @_;
            confess 'Cannot set input on Event if publishtype is OUTPUT'
                if $self->publishtype == +PUBLISH_OUTPUT;
            confess 'Cannot set inout if there is no publisher'
                if not $self->has_publisher;
        },
    );
}

1;

__END__

=head1 DESCRIPTION

POEx::PubSub::Event is a simple abstraction for published and 
subscribed events within PubSub. When using the find_event method or the
listing method from PubSub, you will receive this object.
