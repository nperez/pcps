package POE::Component::PubSub;

use warnings;
use strict;

our $VERSION = '0.01';

use POE;
use Carp;

use constant
{
	'EVENTS'		=>	0,
    'PUBLISHER'     =>  0,
    'SUBSCRIBERS'   =>  1,
};

sub new()
{
	my $class = shift(@_);
	my $self = [];
	$self->[+EVENTS] = {};

	bless($self, $class);

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

}

sub _start()
{
}

sub _stop()
{
}

sub _default()
{
    my ($kernel, $self, $sender, $event, $arg) = 
        @_[KERNEL, OBJECT, SENDER, ARG0, ARG1];

    if(!$self->_is_published($event))
    {
        Carp::carp('$event is not published');
        return;
    }

    if(!$self->_owns($sender->ID(), $event))
    {
        Carp::carp('$event is not owned by $sender');
        return;
    }

    if(!$self->_has_subscribers($event))
    {
        Carp::carp('$event currently has no subscribers');
        return;
    }

    my $subs = $self->_get_subs();
    
    while (my ($subscriber, $return) = each %{ $subs })
    {
        if(!$self->_has_event($subscriber, $return))
        {
            Carp::carp("$subscriber no longer has $return in their events");
            $removed->{$subscriber} = $event;
        }
        
        $kernel->post($subscriber, $return, @$arg);
    }

}

sub listing()
{
    my ($kernel, $self, $sender, $return) = @_[KERNEL, OBJECT, SENDER, ARG0];

    # XXX return listing if no $sender/$return;
    # else return results to $sender -> $return event;
}

sub publish()
{
	my ($kernel, $self, $sender, $event) = 	@_[KERNEL, OBJECT, SENDER, ARG0];
		
	if(!defined($event))
	{
		Carp::carp('$event argument is required for publishing');
        return;
	}
    
    if($self->_is_published($event))
    {
        Carp::carp('$event already exists');
        return;
    }

	$self->_add_pub($sender->ID(), $event);
	
}

sub subscribe()
{
	my ($kernel, $self, $sender, $event, $return) = 
        @_[KERNEL, OBJECT, SENDER, ARG0, ARG1];

	if(!defined($event))
	{
		Carp::carp('$event argument is required for subscribing');
        return;
	}

    if(!$self->_is_published($event))
    {
        Carp::carp('$event must first be published');
        return;
    }
	
	if(!$self->_has_event($sender, $return))
	{
	    Carp::carp($sender . ' must own the ' . $event . ' event');
        return;
	}

    $self->_add_sub($sender->ID, $event, $return);
}

sub recind()
{
    my ($kernel, $self, $sender, $event) = 
        @_[KERNEL, OBJECT, SENDER, ARG0];

    if(!defined($event))
	{
		Carp::carp('$event argument is required for recinding');
        return;
	}

    if(!$self->_is_published($event))
    {
        Carp::carp('$event is not published');
        return;
    }

    if(!$self->_owns($sender->ID(), $event))
    {
        Carp::carp('$event is not owned by $sender');
        return;
    }

    if($self->_has_subscribers($event))
    {
        Carp::carp('$event currently has subscribers, but removing anyway');
    }
    
    $self->_remove_pub($sender->ID(), $event);

}

sub cancel()
{
    my ($kernel, $self, $sender, $event) = 
        @_[KERNEL, OBJECT, SENDER, ARG0];
    
    if(!defined($event))
	{
		Carp::carp('$event argument is required for canceling');
        return;
	}
    
    if(!$self->_has_event($sender, $event))
    {
        Carp::carp($sender . ' must own the ' . $event . ' event');
        return;
    }

    if(!$self->_is_published($event))
    {
        Carp::carp('$event is not published');
        return;
    }

    $self->_remove_sub($sender->ID(), $event);

}

# EVIL: We need to do some checking to make sure subscribers actually have the 
# events they claim to have. I didn't want to have a dependency on 
# POE::API::Peek and the subsequent Devel::Size, so I ripped out what concepts
# I needed to implement this.
sub _events()
{
	my ($self, $session) = @_;
	
	if(ref($session) =~ m/POE::SESSION/)
	{
		return \@{ keys( %{ $session->[ &POE::Session::SE_STATES() ] } ) };
	
	} else {
		
		my $ref = $poe_kernel->ID_id_to_session($session);

		if(defined($ref))
		{
			return \@{ keys( %{ $ref->[ &POE::Session::SE_STATES() ] } ) };
		
		} else {

			return undef;
		}
	}
}

sub _has_event()
{
	my ($self, $session, $event) = @_;

	return scalar( grep( m/$event/, @{ $self->_events( $session ) } ) );
}

sub _is_published()
{
    my ($self, $event) = @_;
    return exists($self->[+EVENTS]->{$event});
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

