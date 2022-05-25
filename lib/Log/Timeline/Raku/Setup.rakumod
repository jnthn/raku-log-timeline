use v6.d;
use Log::Timeline::Raku::LogTimelineSchema;

with %*ENV<LOG_TIMELINE_RAKU_EVENTS> {
    for .split(',') -> $event {
        given $event {
            when 'file' {
                setup-file-logging();
                CATCH {
                    default {
                        warn "Failed to set up file logging: $_";
                    }
                }
            }
            when 'thread' {
                setup-thread-logging();
                CATCH {
                    default {
                        warn "Failed to set up thread logging: $_";
                    }
                }
            }
            default {
                warn "Unsupported Log::Timeline Raku event '$event'";
            }
        }
    }
}

sub setup-file-logging() {
    my $handle-lock = Lock.new;
    my Log::Timeline::Ongoing %handles{IO::Handle};

    IO::Handle.^lookup('open').wrap: -> IO::Handle $handle, |c {
        my \result = callsame;
        if result !~~ Failure {
            my $path = ~$handle.path;
            $handle-lock.protect: {
                %handles{$handle} = Log::Timeline::Raku::LogTimelineSchema::FileOpen.start(:$path);
            };
        }
        result
    };

    IO::Handle.^lookup('close').wrap: -> IO::Handle $handle, |c {
        my Log::Timeline::Ongoing $task = $handle-lock.protect: { %handles{$handle}:delete };
        $task.end if $task;
        callsame;
    }
}

sub setup-thread-logging() {
    my $thread-lock = Lock.new;
    my Log::Timeline::Ongoing %threads{Thread};

    Thread.^lookup('run').wrap(-> Thread $thread, |c {
        my \result = callsame;
        $thread-lock.protect: {
            %threads{$thread} = Log::Timeline::Raku::LogTimelineSchema::RunThread.start:
                    :id($thread.id), :name($thread.name);
        };
        result
    });

    Thread.^lookup('finish').wrap(-> Thread $thread, |c {
        my \result = callsame;
        my Log::Timeline::Ongoing $task = $thread-lock.protect: { %threads{$thread}:delete };
        $task.end if $task;
        result
    });

    Thread.start(-> {}).finish;
}

