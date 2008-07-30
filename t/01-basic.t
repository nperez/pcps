#!perl -T
use warnings;
use strict;

use Test::More tests => 10;
use POE;

#start it off
BEGIN
{
    use_ok('POE::Component::PubSub');
    use_ok('POE::Component::PubSub::Status');
}

#helper subs for instantiation
sub test_new_pcps_fail
{
    my ($name, @args) = @_;
    eval { POE::Component::PubSub->new(@args); };
    ok( $@ ne '', $name );
}

sub test_new_pcps_succeed
{
    my ($name, @args) = @_;
    eval { POE::Component::PubSub->new(@args); };
    ok( $@ eq '', $name );
}

#make sure we have all of the constants we need
can_ok
(
    'POE::Component::PubSub' 
    qw/ 
        PCPS_NOT_PUBLISHED
        PCPS_NOT_OWNED
        PCPS_NO_SUBSCRIBERS
        PCPS_INVALID_EVENT
        PCPS_EVENT_EXISTS
    /
);

#start it up
test_new_pcps_succeed('Instantiate with alias', 'ALIAS' => 'MyPubSub');

#create a producer
POE::Session->create
(
    'inline_states' =>
    {
        '_start' =>
            sub
            {
                $_[KERNEL]->alias_set('producer');
                $_[KERNEL]->yield('publish');
            },
        '_stop' =>
            sub
            {
                $_[KERNEL]->alias_remove('producer');
            },
        'publish' =>
            sub
            {
                $_[KERNEL]->post
                (
                    'MyPubSub', 
                    'publish',
                    1,
                    'status',
                    'new_message'
                );
            },
        'status' =>
            sub
            {
                if($_[ARG0] == 1 && $_[ARG1] == +PCPS_OK)
                {
                    pass('Published event');
                }
                if($_[ARG0] == 3 && $_[ARG1] == +PCPS_OK)
                {
                    pass('Event fired successfully');
                }
                
            },
        'fire_message' =>
            sub
            {
                $_[KERNEL]->post
                (
                    'MyPubSub',
                    'new_message',
                    3,
                    'status',
                    'This is the message',
                );

            },
    }
);
