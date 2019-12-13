use Log::Timeline::Model;
use Log::Timeline::Output::JSONLines;
use Log::Timeline::Output::Socket;
use Log::Timeline::Source::MoarVM;

class Log::Timeline {
    #| Check if an output of some kind is set up for logging.
    method has-output() {
        PROCESS::<$LOG-TIMELINE-OUTPUT>.defined
    }
}

# The mainline of a module runs once. We use this to do the setup phase of
# the desired output, based on environment variables.
with %*ENV<LOG_TIMELINE_SERVER> {
    when /^ \d+ $/ {
        PROCESS::<$LOG-TIMELINE-OUTPUT> = Log::Timeline::Output::Socket.new(port => +$/);
    }
    when /^ (.+) ':' (\d+) $/ {
        PROCESS::<$LOG-TIMELINE-OUTPUT> = Log::Timeline::Output::Socket.new(host => ~$0, port => +$1);
    }
    default {
        die "Expected LOG_TIMELINE_SERVER to contain a port number or host:port";
    }
}
orwith %*ENV<LOG_TIMELINE_JSON_LINES> {
    PROCESS::<$LOG-TIMELINE-OUTPUT> = Log::Timeline::Output::JSONLines.new(path => .IO);
}
END try .close with PROCESS::<$LOG-TIMELINE-OUTPUT>;

# With that in place, we also try to set up any runtime events we might produce.
if Log::Timeline.has-output && !PROCESS::<$LOG-TIMELINE-NO-RUNTIME-EVENTS> {
    Log::Timeline::Source::MoarVM::start();
}
