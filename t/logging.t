use Log::Timeline;
use Test;

# Fake output recorder for test purposes.
my class FakeOutput does Log::Timeline::Output {
    has @.entries;

    method log-event($type, Int $parent-id, Instant $timestamp, %data --> Nil) {
        @!entries.push: { :event, :$type, :$parent-id, :%data }
    }

    method log-start($type, Int $parent-id, Int $id, Instant $timestamp, %data --> Nil) {
        @!entries.push: { :start, :$type, :$parent-id, :$id, :%data }
    }

    method log-end($type, Int $id, Instant $timestamp --> Nil) {
        @!entries.push: { :end, :$type, :$id }
    }

    method close(--> Nil) { }
}

class My::Test::EventA does Log::Timeline::Event['TestApp', 'Test Cat 1', 'EvA'] { }
class My::Test::EventB does Log::Timeline::Event['TestApp', 'Test Cat 2', 'EvB'] { }

lives-ok { My::Test::EventA.log(), },
        'Logging an event is a no-op if no output';

given FakeOutput.new -> FakeOutput $output {
    PROCESS::<$LOG-TIMELINE-OUTPUT> = $output;
    LEAVE PROCESS::<$LOG-TIMELINE-OUTPUT> = Nil;

    lives-ok { My::Test::EventA.log() },
            'Can log an event with no data';
    lives-ok { My::Test::EventB.log(foo => 42) },
            'Can log an event with data';

    is $output.entries.elems, 2, 'Got expected output';
    is-deeply $output.entries[0],
            { :event, :type(My::Test::EventA), :parent-id(0), :data{} },
            'First event logged correctly';
    is-deeply $output.entries[1],
            { :event, :type(My::Test::EventB), :parent-id(0), :data{ foo => 42 } },
            'Second event logged correctly with its data';
}

my class My::Test::TaskA does Log::Timeline::Task['TestApp', 'Test Cat 1', 'Task A'] { }
my class My::Test::TaskB does Log::Timeline::Task['TestApp', 'Test Cat 2', 'Task B'] { }

lives-ok { My::Test::TaskA.log(-> { }) },
        'Logging a task is a no-op if no output (using .task)';
lives-ok { My::Test::TaskA.start.end },
        'Logging a task is a no-op if no output (using .start / .end)';

given FakeOutput.new -> FakeOutput $output {
    PROCESS::<$LOG-TIMELINE-OUTPUT> = $output;
    LEAVE PROCESS::<$LOG-TIMELINE-OUTPUT> = Nil;

    my $run = False;
    My::Test::TaskA.log: {
        $run = True;
    }
    ok $run, 'Can log a task with no data and the task code is run';
    is $output.entries.elems, 2, 'Have two logged events';
    is-deeply $output.entries[0],
            { :start, :type(My::Test::TaskA), :parent-id(0), :id(1), :data{} },
            'Correct start entry logged by log';
    is-deeply $output.entries[1],
            { :end, :type(My::Test::TaskA), :id(1) },
            'Correct end entry logged by log';

    $output.entries = ();
    my $task = My::Test::TaskB.start;
    is $output.entries.elems, 1, 'Can log an individual start event';
    is-deeply $output.entries[0],
            { :start, :type(My::Test::TaskB), :parent-id(0), :id(2), :data{} },
            'Correct start entry logged by start';
    $task.end;
    is $output.entries.elems, 2, 'Can log an individual end event';
    is-deeply $output.entries[1],
            { :end, :type(My::Test::TaskB), :id(2) },
            'Correct end entry logged by end';
}

done-testing;
