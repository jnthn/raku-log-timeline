use Log::Timeline::Output;

#| Sends output over a socket.
class Log::Timeline::Output::Socket does Log::Timeline::Output {
    #| The host to listen on.
    has Str $.host = 'localhost';

    #| The port to listen for connections on.
    has Int $.port is required;

    #| Promise kept when we need to start closing.
    has $!closing = Promise.new;

    #| Promise kept once we have shut down, which corresponds to the reactor for
    #| processing events terminating.
    has $!reactor-done = self!start-reactor.Promise;

    #| The reactor starts the server, listens for events that we should log, and
    #| sends them. It also saves events up until the initial connection. It is
    #| assumed there will be a single active connection in most use cases.
    method !start-reactor() {
        supply {
            my %connections{IO::Socket::Async} is Hash;

            whenever IO::Socket::Async.listen($!host, $!port) -> $conn {

            }

            whenever $!closing {
                done;
            }
        }
    }


    method log-event($type, Int $parent-id, Instant $timestamp, %data --> Nil) {

    }

    method log-start($type, Int $parent-id, Int $id, Instant $timestamp, %data --> Nil) {

    }

    method log-end($type, Int $id, Instant $timestamp --> Nil) {

    }

    #| Close the socket, once all outstanding events are sent.
    method close(--> Nil) {
        $!closing.keep;
        await $!reactor-done;
    }
}
