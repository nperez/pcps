use MooseX::Declare;

use Test::More;
use POE;
use POEx::PubSub;

my $pubalias = 'pub_alias';
my $publisher = 'publisher';
my $subscriber = 'subscriber';
my $master = 'master';
my $stop = 0;

POEx::PubSub->new(alias => $pubalias, options => { trace => 1, debug => 1});

class PuppetMaster 
{
    with 'POEx::Role::SessionInstantiation';
    use aliased 'POEx::Role::Event';
    use Test::More;
    
    after _start is Event
    {
        $self->post($pubalias, 'publish', session => $publisher, event_name => 'yarg');
        $self->post($pubalias, 'subscribe', session => $subscriber, event_name => 'yarg', event_handler => 'foo');
        $self->post($publisher, 'blah', 'yarg');
    }
}

class Publisher
{
    with 'POEx::Role::SessionInstantiation';
    use aliased 'POEx::Role::Event';
    use Test::More;
    use POEx::PubSub;

    after _start is Event
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

    method bar_input (Int $arg) is Event
    {
        pass('bar fired: '. $arg);
        
        if($arg == 4)
        {
            $stop = 1;
            return;
        }
        else
        {
            $self->post($pubalias, 'step'.$arg, $arg);
        }
    }
    
    method blah(Str $event) is Event
    {
        pass('blah fired');
        $self->post($pubalias, $event);
        $self->yield('bar_input', 1);
    }
}

class Subscriber
{
    with 'POEx::Role::SessionInstantiation';
    use aliased 'POEx::Role::Event';
    use Test::More;

    after _start is Event
    {
        $self->post($pubalias, 'subscribe', event_name => 'step1', event_handler => 'handler');
        $self->post($pubalias, 'subscribe', event_name => 'step2', event_handler => 'handler');
        $self->post($pubalias, 'subscribe', event_name => 'step3', event_handler => 'handler');
    }

    method handler(Int $arg) is Event
    {
        pass('handler fired: '.$arg);
        $self->post($pubalias, 'bar', ++$arg);
    }

    method foo is Event
    {
        pass('foo fired');
    }
}

Publisher->new(alias => $publisher, options => { trace => 1, debug => 1});
Subscriber->new(alias => $subscriber, options => { trace => 1, debug => 1});
PuppetMaster->new(alias => $master, options => { trace => 1, debug => 1});

POE::Kernel->run();

is($stop, 1, 'Reached the final event');

done_testing();
