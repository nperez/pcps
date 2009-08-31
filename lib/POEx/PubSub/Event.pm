package POEx::PubSub::Event;

#ABSTRACT: An event abstraction for POEx::PubSub

use 5.010;
use MooseX::Declare;

class POEx::PubSub::Event
{
    use MooseX::AttributeHelpers;
    use POEx::PubSub::Types(':all');
    use MooseX::Types::Moose(':all');

=attr name

The name of the event.

=cut
    has name =>
    (
        is          => 'rw',
        isa         => Str,
        required    => 1,
    );

=attr subscribers, predicate => 'has_subscribers', clearer => 'clear_subscribers

The event's subscribers stored in a Set::Object

=cut

=method all_subscribers()
    
This method is delegated to the subscribers attribute to return all of the
subscribers for this event

=cut

=method add_subscriber(Subscriber $sub)

Add the supplied subscriber to the event

=cut

=method remove_subscriber(Subscriber $sub)

Remove the supplied subscriber from the event

=cut

    has subscribers =>
    (
        metaclass   => 'Collection::Hash',
        is          => 'rw', 
        isa         => HashRef[Subscriber], 
        default     => sub { {} },
        lazy        => 1,
        clearer     => 'clear_subscribers',
        provides    =>
        {
            values  => 'all_subscribers',
            count   => 'has_subscribers',
            set     => 'add_subscriber',
            delete  => 'remove_subscriber',
            get     => 'get_subscriber',
        }
    );

=attr publisher, predicate => 'has_publisher'

The event's publisher.

=cut

    has publisher =>
    (
        is          => 'rw',
        isa         => Str,
        predicate   => 'has_publisher',
    );

=attr publishtype, isa => PublishType

The event's publish type. 

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

=attr input, predicate => 'has_input'

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
