use Log::Timeline;
use JSON::Fast;
use Test;

my constant $TEST_PORT = 19893;
PROCESS::<$LOG-TIMELINE-OUTPUT> = Log::Timeline::Output::Socket.new(port => $TEST_PORT);
END PROCESS::<$LOG-TIMELINE-OUTPUT>.close;

class My::Test::EventA does Log::Timeline::Event['TestApp', 'Test Cat 1', 'EvA'] {

}
class My::Test::EventB does Log::Timeline::Event['TestApp', 'Test Cat 2', 'EvB'] {

}
class My::Test::TaskA does Log::Timeline::Task['TestApp', 'Test Cat 1', 'Task A'] {

}
class My::Test::TaskB does Log::Timeline::Task['TestApp', 'Test Cat 2', 'Task B'] {

}

ok Log::Timeline.has-output, 'We have output configured for Log::Timeline';

my $task-a;
lives-ok
        { $task-a = My::Test::TaskA.start(propa => 'foo') },
        'Can start a task before the client opens a socket connection';
lives-ok
        { My::Test::EventB.log($task-a, propb => 'bar') },
        'Can log an event before the client opens a socket connection';

my $conn;
lives-ok
        { $conn = await IO::Socket::Async.connect('localhost', $TEST_PORT) },
        'Can connect to the socket server';

my $received = '';
react {
    whenever $conn.Supply {
        $received ~= $_;
        done;
    }
    whenever Promise.in(1) {
        done;
    }
}
is $received, '', 'Server did not send anything before the client did';

lives-ok { await $conn.print: Q:b/{ "min": 1, "max": 1 }\n/ },
        'Could send initial handshake message';

my @handshake;
my @prior-events;
react {
    whenever $conn.Supply.lines {
        if @handshake {
            push @prior-events, $_;
            done if @prior-events == 2;
        }
        else {
            push @handshake, $_;
        }
    }
    whenever Promise.in(10) {
        diag 'Timeout while waiting for first events';
        done;
    }
}
is @handshake.elems, 1, 'Received handshake message';
given from-json(@handshake[0]) {
    is-deeply .<ver>, 1, 'Server send back confirmation of version';
}
is @prior-events.elems, 2, 'Got two events sent over the socket';
given from-json(@prior-events[0]) {
    isa-ok $_, Hash, 'Entry deserialized to a Hash (1)';
    is .<m>, 'TestApp', 'Correct module (1)';
    is .<c>, 'Test Cat 1', 'Correct category (1)';
    is .<n>, 'Task A', 'Correct name (1)';
    is .<k>, 1, 'Correct kind (1)';
    is .<i>, 1, 'Correct ID (1)';
    is .<p>, 0, 'Correct parent (1)';
    is-deeply .<d>, { propa => 'foo' }, 'Correct data (1)';
    ok .<t>:exists, 'Has a timestamp (1)';
}
given from-json(@prior-events[1]) {
    isa-ok $_, Hash, 'Entry deserialized to a Hash (2)';
    is .<m>, 'TestApp', 'Correct module (2)';
    is .<c>, 'Test Cat 2', 'Correct category (2)';
    is .<n>, 'EvB', 'Correct name (2)';
    is .<k>, 0, 'Correct kind (2)';
    is .<p>, 1, 'Correct parent (2)';
    is-deeply .<d>, { propb => 'bar' }, 'Correct data (2)';
    ok .<t>:exists, 'Has a timestamp (2)';
}

my @next-event;
react {
    whenever $conn.Supply.lines {
        push @next-event, $_;
        done;
    }
    whenever Promise.in(10) {
        diag 'Timeout while waiting for next event';
        done;
    }

    lives-ok { $task-a.end() }, 'Can end task started before socket open';
}
is @next-event.elems, 1, 'Got end event on existing connection';
given from-json(@next-event[0]) {
    isa-ok $_, Hash, 'Entry deserialized to a Hash (3)';
    is .<m>, 'TestApp', 'Correct module (3)';
    is .<c>, 'Test Cat 1', 'Correct category (3)';
    is .<n>, 'Task A', 'Correct name (3)';
    is .<k>, 2, 'Correct kind (3)';
    is .<i>, 1, 'Correct ID (3)';
    ok .<t>:exists, 'Has a timestamp (3)';
}

$conn.close;

subtest 'Handles lack of JSON input' => {
    lives-ok
            { $conn = await IO::Socket::Async.connect('localhost', $TEST_PORT) },
            'Can make another connection to the server';
    @handshake = ();
    my $timed-out = False;
    react {
        whenever $conn.Supply.lines {
            push @handshake, $_;
            LAST done;
        }
        whenever Promise.in(10) {
            $timed-out = True;
            done;
        }
        await $conn.print("not even JSON\n");
    }
    is @handshake.elems, 1, 'Got a response on bad handshake';
    ok from-json(@handshake[0])<err>:exists, 'Server sent an error';
    nok $timed-out, 'Server closed the bad connection attemt';
}

subtest 'Handles unknown version' => {
    lives-ok
            { $conn = await IO::Socket::Async.connect('localhost', $TEST_PORT) },
            'Can make another connection to the server';
    @handshake = ();
    my $timed-out = False;
    react {
        whenever $conn.Supply.lines {
            push @handshake, $_;
            LAST done;
        }
        whenever Promise.in(10) {
            $timed-out = True;
            done;
        }
        await $conn.print(Q:b/{ "min": 42, "max": 44 }\n/);
    }
    is @handshake.elems, 1, 'Got a response on bad handshake';
    ok from-json(@handshake[0])<err>:exists, 'Server sent an error';
    nok $timed-out, 'Server closed the bad connection attemt';
}

done-testing;
