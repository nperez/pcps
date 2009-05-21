package POE::Component::PubSub;

#ABSTRACT: A publish/subscribe component for the POE framework

=head1 SYNOPSIS
    
    #imports PUBLISH_INPUT and PUBLISH_OUTPUT
    use POE::Component::PubSub;
    
    # Instantiate the publish/subscriber with the alias "pub"
    POE::Component::PubSub->new(alias => 'pub');

    # Publish an event called "FOO". +PUBLISH_OUTPUT is actually optional.
    $_[KERNEL]->post
    (
        'pub', 
        'publish', 
        event_name => 'FOO', 
        publish_type => +PUBLISH_OUTPUT
    );

    # Elsewhere, subscribe to that event, giving it an event to call
    # when the published event is fired.
    $_[KERNEL]->post
    (
        'pub', 
        'subscribe', 
        event_name => 'FOO', 
        event_handler => 'FireThisEvent'
    );

    # Fire off the published event
    $_[KERNEL]->post('pub', 'FOO');

    # Publish an 'input' event
    $_[KERNEL]->post
    (
        'pub', 
        'publish', 
        event_name => 'BAR', 
        publish_type => +PUBLISH_INPUT, 
        input_handler =>'MyInputEvent'
    );

    # Publish an event for another session
    $_[KERNEL]->post
    (
        'pub',
        'publish',
        session => 'other_session',
        event_name => 'SomeEvent',
    );

    # Subscribe to an event for another session
    $_[KEREL]->post
    (
        'pub',
        'publish,
        session => 'other_session',
        event_name => 'SomeEvent',
        event_handler => 'other_sessions_handler',
    );

    # Tear down the whole thing
    $_[KERNEL]->post('pub', 'destroy');
=cut

use 5.010;
use MooseX::Declare;

class POE::Component::PubSub with POEx::Role::SessionInstantiation
{
    use Carp('carp', 'confess');
    use POE::API::Peek;
    use POE::Component::PubSub::Types(':all');
    use POE::Component::PubSub::Event;
    use MooseX::AttributeHelpers;
    
    sub import
    {
        no strict 'refs';
        my $caller = caller();
        *{ $caller . '::PUBLISH_INPUT' } = \&PUBLISH_INPUT;
        *{ $caller . '::PUBLISH_OUPUT' } = \&PUBLISH_OUPUT;
    }
    
=attr _api_peek
    $pubsub->_api_peek

This is a private attribute for accessing POE::API::Peek.
=cut 
    
    has _api_peek =>
    (
        is          => 'ro',
        isa         => 'POE::API::Peek',
        default     => sub { POE::API::Peek->new() },
        lazy        => 1,
    );

=attr _events 
    $pubsub->_events

This is a private attribute for accessing the PubSub::Events stored in this 
instance of PubSub.  
=cut

    has _events => 
    (
        metaclass   => 'MooseX::AttributeHelpers::Collection::Hash',
        is          => 'rw', 
        isa         => 'HashRef[POE::Component::PubSub::Event]',
        clearer     => '_clear__events',
        default     => sub { {} },
        lazy        => 1,
        provides    =>
        {
            values  => 'all_events',
            set     => 'add_event',
            delete  => 'remove_event',
            get     => 'get_event',
            count   => 'has_events',
        }
    );

=method _default(@args)

After an event is published, the publisher may arbitrarily fire that event to
this component and the subscribers will be notified by calling their respective
return events with whatever arguments are passed by the publisher. The event 
must be published, owned by the publisher, and have subscribers for the event
to be propagated. If any of the subscribers no longer has a valid return event
their subscriptions will be cancelled and a warning will be carp'd.

=cut

    method _default(@args)
    {
        my $poe = $self->poe;
        my $state = $poe->state;
        my $warn = $self->options->{'debug'};

        if(my $event = $self->get_event($state))
        {
            if($event->publishtype == +PUBLISH_OUTPUT)
            {
                my $sender = $poe->sender->ID;
                if(!$event->has_publisher || !$event->publisher == $sender)
                {
                    carp("Event [ $event ] is not owned by Sender: " . $sender) if $warn;
                    return;
                }

                if(!$event->has_subscribers)
                {
                    carp("Event[ $event ] currently has no subscribers") if $warn;
                    return;
                }

                foreach my $subscriber ($event->all_subscribers)
                {
                    my ($s_session, $s_event) = @{ $subscriber }{'session', 'event'};
                    if(!$self->_has_event(session => $s_session, event_name => $s_event))
                    {
                        carp("$s_session no longer has $s_event in their events") if $warn;
                        $self->remove_subscriber($s_session);
                    }
                    
                    $self->post($s_session, $s_event, @args);
                }
                return;
            }
            else
            {
                $self->post(
                    $poe->kernel->ID_id_to_session($event->publisher), 
                    $event->input, 
                    @args);
            }
        }
        else
        {
            carp("Event [ $state ] does not currently exist") if $warn;
            return;
        }
    }

=method destroy

This event will simply destroy any of its current events and remove any and all
aliases this session may have picked up. This should free up the session for
garbage collection.

=cut

    method destroy()
    {
        $self->_clear__events;
        my $kernel = $self->poe->kernel;
        $kernel->alias_remove($_) for $kernel->alias_list();
    }

=method listing(SessionAlias|SessionID|SessionRef|DoesSessionInstantiation :$session?, Str :$return_event?) returns (ArrayRef[POE::Component::PubSub::Event])

To receive a listing of all the of the events inside of PubSub, you can either
call this event and have it returned immediately, or return_event must be 
provided and implemented in either the provided session or SENDER and the only
argument to the return_event will be the events.

=cut

    method listing(SessionAlias|SessionID|SessionRef|DoesSessionInstantiation :$session?, Str :$return_event?) returns (ArrayRef[POE::Component::PubSub::Event])
    {
        if($return_event && $session)
        {
            $session ||= $self->poe->sender->ID;
            $session = is_SessionID($session) ? $session : to_SessionID($session) or confess("Unable to coerce $session to SessionID");
            
            if(!$self->_has_event(session => $session, event_name => $return_event))
            {
                carp("$session must own the $return_event event") if $self->options->{'debug'}; 
                return;
            }
        }

        my $events = [$self->all_events];
    
        $self->poe->kernel->post($session, $return_event, $events) if $return_event;
        return $events;
    }

=method publish(SessionAlias|SessionID|SessionRef|DoesSessionInstantiation :$session?, Str :$event_name!, PublishType :$publish_type?, Str :$input_handler?)

This is the event to use to publish events. The published event may not already
be previously published. The event may be completely arbitrary and does not 
require the publisher to implement that event. Think of it as a name for a 
mailing list.

You can also publish an 'input' or inverse event. This allows for arbitrary
sessions to post to your event. In this case, you must supply the optional
published event type and the event to be called when the published event fires. 

There are two types: PUBLISH_INPUT and PUBLISH_OUTPUT. PUBLISH_OUPUT is implied
when no argument is supplied.

Also, you can publish an event from an arbitrary session as long as you provide
a session alias.

=cut

    method publish(SessionAlias|SessionID|SessionRef|DoesSessionInstantiation :$session?, Str :$event_name!, PublishType :$publish_type?, Str :$input_handler?)
    {
        $session ||= $self->poe->sender->ID;
        $session = is_SessionID($session) ? $session : to_SessionID($session) or confess("Unable to coerce $session to SessionID");
        my $warn = $self->options->{'debug'};

        if(my $event = $self->get_event($event_name))
        {
            if($event->has_publisher)
            {
                carp("Event [ $event_name ] already has a publisher") if $warn;
                return;
            }
            
            if(defined($publish_type) && $publish_type == +PUBLISH_INPUT)
            {
                if(!defined($input_handler))
                {
                    carp('$input_handler argument is required for publishing an input event') if $warn;
                    return;
                }

                if(!$self->_has_event(session => $session, event_name => $input_handler))
                {
                    carp("$session must own the $input_handler event") if $warn;
                    return;
                }

                if($event->has_subscribers)
                {
                    carp("Event [ $event_name ] already has subscribers and precludes publishing") if $warn;
                    return;
                }
            }

            $event->publisher($session);
        }
        else
        {
            my %args;

            if(defined($publish_type) && $publish_type == +PUBLISH_INPUT)
            {
                if(!defined($input_handler))
                {
                    carp('$input_handler argument is required for publishing an input event') if $warn;
                    return;
                }

                if(!$self->_has_event(session => $session, event_name => $input_handler))
                {
                    carp("$session must own the $input_handler event") if $warn;
                    return;
                }
                
                @args{'publishtype', 'input'} = ($publish_type, $input_handler);
            }

            my $event = POE::Component::PubSub::Event->new
            (
                name => $event_name,
                publisher => $session,
                %args
            );

            $self->add_event($event_name, $event);
        }
    }

=method subscribe(SessionAlias|SessionID|SessionRef|DoesSessionInstantiation :$session?, Str :$event_name, Str :$event_handler)

This event is used to subscribe to a published event. The event does not need
to exist at the time of subscription to avoid chicken and egg scenarios. The
event_handler must be implemented in either the provided session or in the 
SENDER. 

=cut
    method subscribe(SessionAlias|SessionID|SessionRef|DoesSessionInstantiation :$session?, Str :$event_name, Str :$event_handler)
    {
        $session ||= $self->poe->sender->ID;
        $session = is_SessionID($session) ? $session : to_SessionID($session) or confess("Unable to coerce $session to SessionID");
        my $warn = $self->options->{'debug'};

        if(my $event = $self->get_event($event_name))
        {
            if($event->publishtype == +PUBLISH_INPUT)
            {
                carp("Event[ $event_name ] is not an output event") if $warn;
                return;
            }

            if(!$self->_has_event(session => $session, event_name => $event_handler))
            {
                carp("$session must own the $event_handler event") if $warn;
                return;
            }

            $event->add_subscriber($session => {session => $session, event => $event_handler});
        }
        else
        {
            my $event = POE::Component::PubSub::Event->new(name => $event_name);
            $event->add_subscriber($session => {session => $session, event => $event_handler});
            $self->add_event($event_name, $event);
        }
    }

=method rescind(SessionAlias|SessionID|SessionRef|DoesSessionInstantiation :$session?, Str :$event_name)

Use this event to stop publication of an event. The event must be published by
either the provided session or SENDER

=cut

    method rescind(SessionAlias|SessionID|SessionRef|DoesSessionInstantiation :$session?, Str :$event_name)
    {
        $session ||= $self->poe->sender->ID;
        $session = is_SessionID($session) ? $session : to_SessionID($session) or confess("Unable to coerce $session to SessionID");
        my $warn = $self->options->{'debug'};

        if(my $event = $self->get_event($event_name))
        {
            if($event->publisher != $session)
            {
                carp("Event[ $event_name ] is not owned by $session") if $warn;
            }

            if($event->has_subscribers)
            {
                carp("Event[ $event_name ] currently has subscribers, but removing anyway") if $warn;
            }
            
            $self->remove_event($event_name);
        }
        else
        {
            carp("Event[ $event_name ] does not exist") if $warn;
        }
    }

=method cancel(SessionAlias|SessionID|SessionRef|DoesSessionInstantiation :$session?, Str :$event_name)

Cancel subscriptions to events with this event. The event must contain the
provided session or SENDER as a subscriber

=cut

    method cancel(SessionAlias|SessionID|SessionRef|DoesSessionInstantiation :$session?, Str :$event_name)
    {
        $session ||= $self->poe->sender->ID;
        $session = is_SessionID($session) ? $session : to_SessionID($session) or confess("Unable to coerce $session to SessionID");
        my $warn = $self->options->{'debug'};
        
        if(my $event = $self->get_event($event_name))
        {
            if(my $subscriber = $event->get_subscriber($session))
            {
                $event->remove_subscriber($session);
            }
            else
            {
                carp("$session must be subscribed to the $event_name event") if $warn;
            }
        }
        else
        {
            carp("Event[ $event_name ] does not exist") if $warn;
        }
    }

    method _has_event(SessionID :$session, Str :$event_name)
    {
        return 0 if not defined($event_name);

        my $session_ref = $self->poe->kernel->ID_id_to_session($session);

        if($session_ref->isa('Moose::Object') && $session_ref->does('POEx::Role::SessionInstantiation'))
        {
            return defined($session_ref->meta->get_method($event_name));
        }
        else
        {
            return scalar ( grep { /$event_name/ } $self->_api_peek->session_event_list($session_ref));
        }
    }
}

1;
__END__
=head1 DESCRIPTION

POE::Component::PubSub provides a publish/subscribe mechanism for the POE
framework allowing sessions to publish events and to also subscribe to those 
events. Firing a published event posts an event to each subscriber of that 
event. Publication and subscription can also be managed from an external
session, but defaults to using the SENDER where possible.

=head1 CLASS METHODS

=over 4

=item new()

This is the constructor for the publish subscribe component. It accepts the
same arguments as any class composed with POEx::Role::SessionInstantiation. 

See POEx::Role::SessionInstantiation for details.

=back
