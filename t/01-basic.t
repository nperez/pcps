use feature ':5.10';
use warnings;
use strict;

use Test::More tests => 9;
use POE;

BEGIN
{
    use_ok('POE::Component::PubSub');
}

my $comp = POE::Component::PubSub->new('pub_alias');
isa_ok($comp, 'POE::Component::PubSub');

POE::Session->create
(
    'inline_states' =>
    {
        '_start' => sub
        {
            $_[KERNEL]->alias_set('runner');
            $_[KERNEL]->yield('continue');
        },
        'continue' => sub
        {
            make_publisher();
            make_subscriber();

            $_[KERNEL]->post('test1', 'fire');
        },
    }
);

POE::Kernel->run();

exit 0;

sub make_publisher()
{
    POE::Session->create
    (
        'inline_states' =>
        {
            '_start' => sub
            {
                $_[KERNEL]->alias_set('test1');
                $_[KERNEL]->yield('publisher');
            },
            
            'publisher' => sub
            {
                $_[KERNEL]->post('pub_alias', 'publish', 'foo');
                $_[KERNEL]->post('pub_alias', 'publish', 'bar', +PUBLISH_INPUT, 'input');
                pass('Published');
            },

            'fire' => sub
            {
                $_[KERNEL]->post('pub_alias', 'foo', 'ARGUMENT');
                pass('Event fired');
            },

            'input' => sub
            {
                pass('input event fired');

                if(defined($_[ARG0]))
                {
                    if($_[ARG0] == 1)
                    {
                        pass('input argument okay');
                        $_[KERNEL]->alias_remove('test1');
                        return;
                    }
                }
                fail('input argument not okay');
            },
        }
    );
}

sub make_subscriber()
{
    POE::Session->create
    (
        'inline_states' =>
        {
            '_start' => sub
            {
                $_[KERNEL]->alias_set('test2');
                $_[KERNEL]->yield('subscriber');
            },
            
            'subscriber' => sub
            {
                $_[KERNEL]->post('pub_alias', 'subscribe', 'foo', 'fired_event');
                pass('Subscribed');
            },

            'fired_event' => sub
            {
                pass('Event received');

                ok($_[ARG0] eq 'ARGUMENT', 'Argument passed successfully');
                
                $_[KERNEL]->post('pub_alias', 'bar', 1);
                $_[KERNEL]->alias_remove('test2');
            }
        }
    );
}
        
