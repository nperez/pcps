use 5.010;
use MooseX::Declare;

use Test::More tests => 10;
use POE;

BEGIN
{
    use_ok('POE::Component::PubSub');
}

my $pubalias = 'pub_alias';
my $publisher = 'publisher';
my $subscriber = 'subscriber';
my $master = 'master';

POE::Component::PubSub->new(alias => $pubalias, options => { trace => 1, debug => 1});

class PuppetMaster with POEx::Role::SessionInstantiation
{
    use Test::More;
    
    after _start
    {
        $self->post($pubalias, 'publish', session => $publisher, event_name => 'yarg');
        $self->post($pubalias, 'subscribe', session => $subscriber, event_name => 'yarg', event_handler => 'foo');
        $self->post($publisher, 'blah', 'yarg');
    }
}

class Publisher with POEx::Role::SessionInstantiation
{
    use Test::More;
    use POE::Component::PubSub;

    after _start
    {
        $self->post($pubalias, 'publish', event_name => 'step1');
        $self->post($pubalias, 'publish', event_name => 'step2');
        $self->post($pubalias, 'publish', event_name => 'step3');
        
        $self->post
        (
            $pubalias, 
            'publish', 
            event_name => 'bar', 
            publish_type => +PUBLISH_INPUT, 
            input_handler => 'bar_input'
        );
    }

    method bar_input (Int $arg)
    {
        pass('bar fired: '. $arg);
        
        if($arg == 4)
        {
            return;
        }
        else
        {
            $self->post($pubalias, 'step'.$arg, $arg);
        }
    }
    
    method blah(Str $event)
    {
        pass('blah fired');
        $self->post($pubalias, $event);
        $self->yield('bar_input', 1);
    }
}

class Subscriber with POEx::Role::SessionInstantiation
{
    use Test::More;

    after _start
    {
        $self->post($pubalias, 'subscribe', event_name => 'step1', event_handler => 'handler');
        $self->post($pubalias, 'subscribe', event_name => 'step2', event_handler => 'handler');
        $self->post($pubalias, 'subscribe', event_name => 'step3', event_handler => 'handler');
    }

    method handler(Int $arg)
    {
        pass('handler fired: '.$arg);
        $self->post($pubalias, 'bar', ++$arg);
    }

    method foo()
    {
        pass('foo fired');
    }
}

Publisher->new(alias => $publisher, options => { trace => 1, debug => 1});
Subscriber->new(alias => $subscriber, options => { trace => 1, debug => 1});
PuppetMaster->new(alias => $master, options => { trace => 1, debug => 1});

POE::Kernel->run();

exit 0;
