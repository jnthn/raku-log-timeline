use Log::Timeline;
use JSON::Fast;
use Test;

my $test-file = $*TMPDIR.add('p6-log-timeline-test');
END try unlink $test-file;
PROCESS::<$LOG-TIMELINE-OUTPUT> = Log::Timeline::Output::JSONLines.new(path => $test-file);

class My::Test::EventA does Log::Timeline::Event['TestApp', 'Test Cat 1', 'EvA'] { }
class My::Test::EventB does Log::Timeline::Event['TestApp', 'Test Cat 2', 'EvB'] { }
class My::Test::TaskA does Log::Timeline::Task['TestApp', 'Test Cat 1', 'Task A'] { }
class My::Test::TaskB does Log::Timeline::Task['TestApp', 'Test Cat 2', 'Task B'] { }

ok Log::Timeline.has-output, 'We have output configured for Log::Timeline';

lives-ok
        {
            My::Test::TaskA.log: propa => 'foo', {
                My::Test::TaskB.log: {
                    My::Test::EventA.log(propb => 'bar');
                }
                My::Test::EventB.log;
            }
        },
        'Can log tasks with the file output logger';
lives-ok { PROCESS::<$LOG-TIMELINE-OUTPUT>.close },
        'Close method works';

my @logged-lines = $test-file.lines;
is @logged-lines.elems, 6, 'Log file has expected number of lines';

given from-json(@logged-lines[0]) {
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

given from-json(@logged-lines[1]) {
    isa-ok $_, Hash, 'Entry deserialized to a Hash (2)';
    is .<m>, 'TestApp', 'Correct module (2)';
    is .<c>, 'Test Cat 2', 'Correct category (2)';
    is .<n>, 'Task B', 'Correct name (2)';
    is .<k>, 1, 'Correct kind (2)';
    is .<i>, 2, 'Correct ID (2)';
    is .<p>, 1, 'Correct parent (2)';
    is-deeply .<d>, { }, 'Correct data (2)';
    ok .<t>:exists, 'Has a timestamp (2)';
}

given from-json(@logged-lines[2]) {
    isa-ok $_, Hash, 'Entry deserialized to a Hash (3)';
    is .<m>, 'TestApp', 'Correct module (3)';
    is .<c>, 'Test Cat 1', 'Correct category (3)';
    is .<n>, 'EvA', 'Correct name (3)';
    is .<k>, 0, 'Correct kind (3)';
    is .<p>, 2, 'Correct parent (3)';
    is-deeply .<d>, { propb => 'bar' }, 'Correct data (3)';
    ok .<t>:exists, 'Has a timestamp (3)';
}

given from-json(@logged-lines[3]) {
    isa-ok $_, Hash, 'Entry deserialized to a Hash (4)';
    is .<m>, 'TestApp', 'Correct module (4)';
    is .<c>, 'Test Cat 2', 'Correct category (4)';
    is .<n>, 'Task B', 'Correct name (4)';
    is .<k>, 2, 'Correct kind (4)';
    is .<i>, 2, 'Correct ID (4)';
    ok .<t>:exists, 'Has a timestamp (4)';
}

given from-json(@logged-lines[4]) {
    isa-ok $_, Hash, 'Entry deserialized to a Hash (5)';
    is .<m>, 'TestApp', 'Correct module (5)';
    is .<c>, 'Test Cat 2', 'Correct category (5)';
    is .<n>, 'EvB', 'Correct name (5)';
    is .<k>, 0, 'Correct kind (5)';
    is .<p>, 1, 'Correct parent (5)';
    is-deeply .<d>, { }, 'Correct data (5)';
    ok .<t>:exists, 'Has a timestamp (5)';
}

given from-json(@logged-lines[5]) {
    isa-ok $_, Hash, 'Entry deserialized to a Hash (6)';
    is .<m>, 'TestApp', 'Correct module (6)';
    is .<c>, 'Test Cat 1', 'Correct category (6)';
    is .<n>, 'Task A', 'Correct name (6)';
    is .<k>, 2, 'Correct kind (6)';
    is .<i>, 1, 'Correct ID (6)';
    ok .<t>:exists, 'Has a timestamp (6)';
}

done-testing;
