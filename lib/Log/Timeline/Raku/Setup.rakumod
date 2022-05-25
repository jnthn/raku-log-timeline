use v6.d;
use Log::Timeline::Raku::LogTimelineSchema;

sub setup-raku-events() is export {
    # No logging in precompilation processes.
    return with %*ENV<RAKUDO_PRECOMP_WITH>;
    # See which Raku events are requested.
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
                when 'socket' {
                    setup-async-socket-logging();
                    CATCH {
                        default {
                            warn "Failed to set up socket logging: $_";
                        }
                    }
                }
                when 'process' {
                    setup-process-logging();
                    CATCH {
                        default {
                            warn "Failed to set up process logging: $_";
                        }
                    }
                }
                when 'start' {
                    setup-start-logging();
                    CATCH {
                        default {
                            warn "Failed to set up start logging: $_";
                        }
                    }
                }
                default {
                    warn "Unsupported Log::Timeline Raku event '$event'";
                }
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

sub setup-async-socket-logging() {
    my $socket-lock = Lock.new;
    my Log::Timeline::Ongoing %sockets{IO::Socket::Async};

    IO::Socket::Async.^lookup('listen').wrap: -> $class, $host, $port, |c {
        my $task = Log::Timeline::Raku::LogTimelineSchema::AsyncSocketListen.start(:$host, :$port);
        my $listen = callsame();
        supply whenever $listen -> $socket {
            $socket-lock.protect: {
                %sockets{$socket} = Log::Timeline::Raku::LogTimelineSchema::AsyncSocketIncoming.start:
                        $task, :host($socket.peer-host), :port($socket.peer-port);
            }
            emit $socket;
            CLOSE $task.end;
        }
    }

    IO::Socket::Async.^lookup('connect').wrap: -> $class, $host, $port, |c {
        my $promise = callsame;
        my $socket-task = Log::Timeline::Raku::LogTimelineSchema::AsyncSocketConnect.start(:$host, :$port);
        my $establish-task = Log::Timeline::Raku::LogTimelineSchema::AsyncSocketEstablish.start($socket-task);
        $promise.then({
        $establish-task.end;
            if $promise.status == Kept {
                $socket-lock.protect: { %sockets{$promise.result} = $socket-task; }
            }
            else {
                $socket-task.end;
            }
        });
        $promise
    }

    IO::Socket::Async.^lookup('close').wrap: -> $socket, |c {
        my \result = callsame;
        my Log::Timeline::Ongoing $task = $socket-lock.protect: { %sockets{$socket}:delete };
        $task.end if $task;
        result
    }
}

sub setup-process-logging() {
    Proc::Async.^lookup('start').wrap: -> Proc::Async $proc, |c {
        my $promise = callsame;
        my $task = Log::Timeline::Raku::LogTimelineSchema::RunProcess.start:
            :command($proc.command.map({ /\s/ ?? qq/"$_"/ !! $_ }).join(' '));
        $promise.then({ $task.end });
        $promise
    }
}

sub setup-start-logging() {
    Promise.^lookup('start').wrap: -> Promise, &code, |c {
        my $file = &code.?file // 'Unknown';
        with $file.index('(') {
            $file .= substr($_ + 1, $file.chars - ($_ + 2));
        }
        my $line = &code.?line // 'Unknown';
        my $start-task = Log::Timeline::Raku::LogTimelineSchema::Start.start(:$file, :$line);
        my $queued-task = Log::Timeline::Raku::LogTimelineSchema::StartQueued.start($start-task);
        my &wrapped-code = -> |c {
            $queued-task.end;
            code(|c)
        }
        my $promise = callwith(Promise, &wrapped-code, |c);
        $promise.then({ $start-task.end });
        $promise
    }
}