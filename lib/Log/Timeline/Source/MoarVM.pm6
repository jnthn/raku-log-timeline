unit module Log::Timeline::Source::MoarVM;
use Log::Timeline::Model;

class GC does Log::Timeline::Task['MoarVM', 'GC', 'Collection'] { }

our sub start() {
    use nqp;
    my class EventQueue is repr('ConcBlockingQueue') {
        method receive() {
            nqp::shift(self)
        }
    }
    Thread.start: :app_lifetime, :name('GC Logging'), {
        my $q := EventQueue.new;
        nqp::vmeventsubscribe($q, nqp::hash('gcevent', array[int].new.WHAT));
        my $init-time = $*INIT-INSTANT;
        loop {
            my ($gc-seq-n, $, $from, $duration, $is-full, $promoted-bytes,
                    $promoted-bytes-since-last-full, $coordinator-thread-id) = $q.receive;
            my %values =
                    "GC seq#" => $gc-seq-n,
                    "Is full" => $is-full,
                    "Promoted bytes" => $promoted-bytes,
                    "Promoted bytes since last full" => $promoted-bytes-since-last-full,
                    "Coordinator thread#" => $coordinator-thread-id;
            GC.log-fixed:
                    $init-time + Duration.new($from / 1_000_000),
                    $init-time + Duration.new(( $from + $duration ) / 1_000_000),
                    |%values;
        }
    }
}
