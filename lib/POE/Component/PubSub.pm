package POE::Component::PubSub;

use feature ':5.10';
use warnings;
use strict;

our $VERSION = '0.01';

use POE::Component::PubSub::Status;
use POE;
use Carp;

use constant
{
	'EVENTS'		=>	0,
    'OPTIONS'       =>  1,
    'PUBLISHER'     =>  0,
    'SUBSCRIBERS'   =>  1,
};

sub new()
{
	my $class = shift(@_);
    my $alias = shift(@_);
	my $self = [];
    $alias //= 'PUBLISH_SUBSCRIBE';

    $self->[+ALIAS] = $alias;

	bless($self, $class);
	
    $self->[+EVENTS] = {};
    $self->_gather_options(\@_);

    $self->[+OPTIONS]->{'alias'} ||= 'PubSub';

	POE::Session->create
	(
		'object_states' =>
		[
			$self =>
			[
				'_start',
				'_stop',
				'_default',
				'publish',
				'subscribe',
				'recind',
                'cancel',
			]
		],

		'options' =>
		{
			'trace'	=>	1,
			'debug'	=>	1,
		}
	);
    
    return $self;
}

sub _start()
{
    my ($kernel, $object) = @_;

    $kernel->alias_set($object->[+OPTIONS]->{'alias'});
    return;
}

sub _stop()
{
    $kernel->alias_remove($object->[+OPTIONS]->{'alias'});
}

sub _default()
{
    my ($kernel, $self, $sender, $event, $args) = 
        @_[KERNEL, OBJECT, SENDER, ARG0, ARG1];

    my ($id, $status, @args) = @$args;
    
    if(!$self->_has_event($sender, $status))
	{
	    Carp::carp($sender . ' must own the ' . $status . ' status event');
        return;
	}
    elsif(!$self->_is_published($event))
    {
        $kernel->post($sender, $status, $id, +PCPS_NOT_PUBLISHED);
        return;
    }

    if(!$self->_owns($sender->ID(), $event))
    {
        $kernel->post($sender, $status, $id, +PCPS_NOT_OWNED);
        return;
    }

    if(!$self->_has_subscribers($event))
    {
        $kernel->post($sender, $status, $id, +PCPS_NO_SUBSCRIBERS);
        return;
    }

    my $subs = $self->_get_subs();
    
    while (my ($subscriber, $return) = each %{ $subs })
    {
        if(!$self->_has_event($subscriber, $return))
        {
            Carp::carp("$subscriber no longer has $return in their events");
            $self->_remove_sub($subscriber, $return);
        }
        
        $kernel->post($subscriber, $return, @$arg);
    }

    $kernel->post($sender, $status, $id, +PCPS_OK);
}

sub listing()
{
    my ($kernel, $self, $sender, $id, $return) 
        = @_[KERNEL, OBJECT, SENDER, ARG0 .. ARG2];

    if(!defined($return))
	{
		Carp::carp('$event argument is required for listing');
        return;
	}
    
    if(!$self->_has_event($sender, $return))
	{
	    Carp::carp($sender . ' must own the ' . $return . ' event');
        return;
	}

    my $events = $self->_all_published_events();

    $kernel->post($sender, $return, $events);
}

sub publish()
{
	my ($kernel, $self, $sender, $id, $status, $event) 
        = @_[KERNEL, OBJECT, SENDER, ARG0 .. ARG2];
	
    if(!$self->_has_event($sender, $status))
	{
	    Carp::carp($sender . ' must own the ' . $status . ' status event');
        return;
	}
	elsif(!defined($event))
	{
        $kernel->post($sender, $status, $id, +PCPS_INVALID_EVENT);
        return;
	}
    elsif($self->_is_published($event))
    {
        $kernel->post($sender, $status, $id, +PCPS_EVENT_EXISTS);
        return;
    }

	$self->_add_pub($sender->ID(), $event);
    $kernel->post($sender, $status, $id, +PCPS_OK);
	
}

sub subscribe()
{
	my ($kernel, $self, $sender, $id, $status, $event, $return) = 
        @_[KERNEL, OBJECT, SENDER, ARG0 .. ARG3];

	if(!$self->_has_event($sender, $status))
	{
	    Carp::carp($sender . ' must own the ' . $status . 'status event');
        return;
	}
	elsif(!defined($event))
	{
        $kernel->post($sender, $status, $id, +PCPS_INVALID_EVENT);
        return;
	}
    elsif(!$self->_is_published($event))
    {
        $kernel->post($sender, $status, $id, +PCPS_NOT_PUBLISHED);
        return;
    }
	elsif(!$self->_has_event($sender, $return))
	{
        $kernel->post($sender, $status, $id, +PCPS_NOT_OWNED);
        return;
	}

    $self->_add_sub($sender->ID, $event, $return);
    $kernel->post($sender, $status, $id, +PCPS_OK);
}

sub recind()
{
    my ($kernel, $self, $sender, $id, $status, $event) = 
        @_[KERNEL, OBJECT, SENDER, ARG0 .. ARG2];

    if(!$self->_has_event($sender, $status))
	{
	    Carp::carp($sender . ' must own the ' . $status . 'status event');
        return;
	}
	elsif(!defined($event))
	{
        $kernel->post($sender, $status, $id, +PCPS_INVALID_EVENT);
        return;
	}
    elsif(!$self->_is_published($event))
    {
        $kernel->post($sender, $status, $id, +PCPS_NOT_PUBLISHED);
        return;
    }
    elsif(!$self->_owns($sender->ID(), $event))
    {
        $kernel->post($sender, $status, $id, +PCPS_NOT_OWNED);
        return;
    }

    if($self->_has_subscribers($event))
    {
        Carp::carp('$event currently has subscribers, but removing anyway');
    }
    
    $self->_remove_pub($sender->ID(), $event);
    $kernel->post($sender, $status, $id, +PCPS_OK);

}

sub cancel()
{
    my ($kernel, $self, $sender, $id, $status, $event) = 
        @_[KERNEL, OBJECT, SENDER, ARG0 .. ARG2];
    
    if(!$self->_has_event($sender, $status))
	{
	    Carp::carp($sender . ' must own the ' . $status . 'status event');
        return;
	} 
    elsif(!defined($event))
	{
		$kernel->post($sender, $status, $id, +PCPS_INVALID_EVENT);
        return;
	}
    elsif(!$self->_has_event($sender, $event))
    {
        $kernel->post($sender, $status, $id, +PCPS_NOT_OWNED);
        return;
    }
    elsif(!$self->_is_published($event))
    {
        $kernel->post($sender, $status, $id, +PCPS_NOT_PUBLISHED);
        return;
    }

    $self->_remove_sub($sender->ID(), $event);
    $kernel->post($sender, $status, $id, +PCPS_OK);

}

# EVIL: We need to do some checking to make sure subscribers actually have the 
# events they claim to have. I didn't want to have a dependency on 
# POE::API::Peek and the subsequent Devel::Size, so I ripped out what concepts
# I needed to implement this.
sub _events()
{
    $DB::single = 1;

	my ($self, $session) = @_;
	
	if(uc(ref($session)) =~ m/POE::SESSION/)
	{
		return [ keys( %{ $session->[ &POE::Session::SE_STATES() ] } ) ] ;
	
	} else {
		
		my $ref = $poe_kernel->ID_id_to_session($session);

		if(defined($ref))
		{
			return [ keys( %{ $ref->[ &POE::Session::SE_STATES() ] } ) ];
		
		} else {

			return undef;
		}
	}
}

sub _has_event()
{
	my ($self, $session, $event) = @_;
    
    my $events = $self->_events( $session );

    $DB::single = 1;
    
    if(defined($events))
    {
	    return scalar( grep( m/$event/, @{ $events } ) );
    }
    else
    {
        return 0;
    }
}

sub _has_subscribers()
{
    my ($self, $event) = @_;
    return scalar( keys %{ $self->[+EVENTS]->{$event}->[+SUBSCRIBERS] } ) ;
}

sub _is_published()
{
    my ($self, $event) = @_;
    return exists($self->[+EVENTS]->{$event});
}

sub _is_subscribed()
{
    my ($self, $subscriber, $event) = @_;
    return exists($self->[+EVENTS]->{$event}->[+SUBSCRIBERS]->{$subscriber});
}

sub _owns()
{
    my ($self, $publisher, $event) = @_;
    return $self->[+EVENTS]->{$event}->[+PUBLISHER] eq $publisher;
}

sub _add_pub()
{
    my ($self, $publisher, $event) = @_;
    $self->[+EVENTS]->{$event} = [];
    $self->[+EVENTS]->{$event}->[+PUBLISHER] = $publisher;
    $self->[+EVENTS]->{$event}->[+SUBSCRIBERS] = {};
    return;
}

sub _add_sub()
{
    my ($self, $subscriber, $event, $return) = @_;
    $self->[+EVENTS]->{$event}->[+SUBSCRIBERS]->{$subscriber} = $return;
    return;
}

sub _del_sub()
{
    my ($self, $subscriber, $event) = @_;
    delete($self->[+EVENTS]->{$event}->[+SUBSCRIBERS]->{$subscriber});
    return;
}

sub _del_pub()
{
    my ($self, $publisher, $event) = @_;
    delete($self->[+EVENTS]->{$event});
    return;
}

sub _get_subs()
{
    my ($self, $event) = @_;
    return \%{ $self->[+EVENTS]->{$event}->[+SUBSCRIBERS] };
}

sub _gather_options()
{
	my ($self, $args) = @_;
	
	my $opts = {};

	while(@$args != 0)
	{
		my $key = lc(shift(@{$args}));
		my $value = shift(@{$args});
		
		if(ref($value) eq 'HASH')
		{
			my $hash = {};
			foreach my $sub_key (keys %$value)
			{
				$hash->{lc($sub_key)} = $value->{$sub_key};
			}
			$opts->{$key} = $hash;
			next;
		}
		$opts->{$key} = $value;
	}

    $self->[+OPTIONS] = $opts;;
}

1;

__END__

=pod

=head1 NAME

POE::Component::PubSub - A generic publish/subscribe POE::Component that 
enables POE::Sessions to publish events to which other POE::Sessions may 
subscribe.

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

# Instantiate the publish/subscriber with the alias "pub"
POE::Component::PubSub->new('pub');

# Publish an event called "FOO"
$_[KERNEL]->post('pub', 'publish', 'FOO');

# Elsewhere, subscribe to that event, giving it an event to call
# when the published event is fired.
$_[KERNEL]->post('pub', 'subscribe', 'FOO', 'FireThisEvent');

# Fire off the published event
$_[KERNEL]->post('pub', 'FOO');

=head1 EVENTS

All public events do some sanity checking to make sure of a couple of things
before allowing the events such as checking to make sure the posting session
actually owns the event it is publishing, or that the event passed as the
return event during subscription is owned by the sender. When one of those 
cases comes up, an error is carp'd, and the event returns without stopping
execution.

=over 4

=item 'publish'

This is the event to use to publish events. It accepts one argument, the event
to publish. The sender of the publish event must own the published event and
the published event may not already be previously published.

=item 'subscribe'

This is the event to use when subscribing to published events. It accepts two
arguments: 1) the published event, and 2) the event name of the subscriber to
be called when the published event is fired. The event must be published prior
to subscription and the sender must own the return event.

=item 'recind'

Use this event to stop publication of an event. It accepts one argument, the 
published event. The event must be published, and published by the sender of
the recind event. If the published event has any subscribers, a warning will
be carp'd but execution will continue.

=item 'cancel'

Cancel subscriptions to events with this event. It accepts one argment, the
published event. The event must be published and the sender must be subscribed
to the event.

=item '_default'

After an event is published, the publisher may arbitrarily fire that event to
this component and the subscribers will be notified by calling their respective
return events with whatever arguments are passed by the publisher. The event 
must be published, owned by the publisher, and have subscribers for the event
to be propagated. If any of the subscribers no longer has a valid return event
their subscriptions will be cancelled and a warning will be carp'd.

=item 'listing'

To receive an array reference containing the events that are currently
published within the component, call this event. It accepts one argument, the 
return event to fire with the listing. The sender must own the return event. 

=back

=head1 CLASS METHODS

=over 4

=item POE::Component::PubSub->new($alias)

This is the constructor for the publish subscribe component. It instantiates
it's own session using the provided $alias argument to set its kernel alias. 
If no alias is provided, the default alias is 'PUBLISH_SUBSCRIBE'.

=back

=head1 NOTES

Right now this component is extremely simple, but thorough when it comes to 
checking the various requirements for publishing and subscribing. Currently, 
there is no mechanism to place meta-subscriptions to the events of the 
component itself. This feature is planned for the next release.

Also, to do some of the checking on whether subscribers own the return events,
some ideas were lifted from POE::API::Peek, and like that module, if there are
changes to the POE core, they may break this module. 

=head1 AUTHOR

Nicholas R. Perez, C<< <nperez at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-poe-component-pubsub at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-PubSub>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Component::PubSub

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-PubSub>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-PubSub>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-PubSub>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Component-PubSub>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Nicholas R. Perez, all rights reserved.

This program is released under the following license: gpl

=cut

