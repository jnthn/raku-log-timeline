# Log::Timeline

When building an application with many ongoing, potentially overlapping,
tasks, we may find ourselves wishing to observe what is going on. We'd like to
log, but with a focus on things that happen over time rather than just
individual events. The `Log::Timeline` module provides a means to do that.

**Status:** while `Log::Timeline` itself works, the things to make it useful
are still to come. It has been published at this point to enable integration
of it into an upcoming Cro release, so HTTP requests and server pipelines can
be logged. An upcoming Comma release will provide a means to visualize the
timeline and observe it live.

## Key features

Currently implemented:

* Log tasks with start and end times
* Log individual events
* Tasks and events can be associated with an enclosing parent task
* Include data with the logged tasks and events
* Have data logged to a file, or exposed over a socket
* Visualize task timelines in [Comma](https://commaide.com/) (from Comma Complete
  2018.5, and will be in Comma Community 2018.7)
* Support by [Cro](https://cro.services/), to offer insight into client
  and server request processing pipelines (from 0.8.1)

Planned:

* Introspect what tasks and events a given distribution can log
* When running on MoarVM, get access to a whole range of VM-level tasks and
  events too, such as GC runs, thread spawns, file open/close, process
  spawning, optimization, etc.
* Turn on/off what is logged at runtime (socket mode only)

## Providing tasks and events in a distribution

Providing tasks and events in your application involves the following steps:

1. Make sure that your `META6.json` contains a `depends` entry for `Log::Timeline`.
2. Create one or more modules whose final name part is `LogTimelineSchema`, which
   declares the available tasks and events. This will be used for tools to
   introspect the available set of tasks and events that might be logged, and
   to provide their metadata.
3. Use the schema module and produce timeline tasks and events in your application
   code.

### The schema module

Your application or module should specify the types of tasks and events it wishes to
log. These are specified in one or more modules, which should be registered in the
`provides` section of the `META6.json`. The **module name's final component** should be
`LogTimelineSchema`. For example, `Cro::HTTP` provides `Cro::HTTP::LogTimelineSchema`.
You may provide more than one of these per distribution.

Every task or event has a 3-part name:

* **Module** - for example, `Cro HTTP`
* **Category** - for example, `Client` and `Server`
* **Name** - for example, `HTTP Request`

These are specified when doing the role for the event or task.

To declare an event (something that happens at a single point in time), do the
`Log::Timeline::Event`. To declare an task (which happens over time) do the
`Log::Timeline::Task` role.

```perl6
unit module MyApp::Log::LogTimelineSchema;
use Log::Timeline;

class CacheExpired does Log::Timeline::Event['MyApp', 'Backend', 'Cache Expired'] { }

class Search does Log::Timeline::Task['My App', 'Backend', 'Search'] { }
```

### Produce tasks and events

Use the module in which you placed the events and/or tasks you wish to log.

```perl6
use MyApp::Log::LogTimelineSchema;
```

To log an event, simply call the `log` method:

```perl6
MyApp::Log::LogTimelineSchema::CacheExpired.log();
```

Optionally passing extra data as named arguments:

```perl6
MyApp::Log::LogTimelineSchema::CacheExpired.log(:$cause);
```

To log a task, also call `log`, but pass a block that will execute the task:

```perl6
MyApp::Log::LogTimelineSchema::Search.log: -> {
    # search is performed here
}
```

Named parameters may also be passed to provide extra data:

```perl6
MyApp::Log::LogTimelineSchema::Search.log: :$query -> {
    # search is performed here
}
```

## Collecting data

### Logging to a file in JSON lines format

Set the `LOG_TIMELINE_JSON_LINES` environment variable to the name of a file
to log to. Each line is an object with the following keys:

* `m` - module
* `c` - category
* `n` - name
* `t` - timestamp
* `d` - data (an object with any extra data)
* `k` - kind (0 = event, 1 = task start, 2 = task end)

A task start (kind 1) and task end (2) will also have:

* `i` - a unique ID for the task, starting from 1, to allow starts and ends to
  be matched up

An event (kind 0) or task start (kind 1) may also have:

* `p` - the parent task ID

### Socket logging

Set the `LOG_TIMELINE_SERVER` environment variable to either:

* A port number, to bind to `localhost` on that port
* A string of the form `host:port`, e.g. `127.0.0.1:5555`

**Warning:** Don't expose the socket server to the internet directly; there
is no authentication or encryption. If really wishing to expose it, bind it to
a local port and then use an SSH tunnel.

#### Handshake

Upon connection the client *must* send a JSON line consisting of an object that
includes the keys:

* `min` - the minimum protocol version that the client understands
* `max` - the maximum protocol version that the client understands

The client *may* include other keys in the object speculatively (for example, if
protocol version 3 supports a key "foo", but it speaks anything from 1 to 3, then
it may include the key "foo", knowing that a previous version of the server will
simply ignore it).

In response to this, the server *must* send a JSON line consisting of an object
that includes *at most one of the following*:

* `ver` - the version number of the protocol that the server will speak, if it is
  understands any of the versions in the range the client proposed
* `err` - an error string explaining why it will not accept the request

In the case of sending an `err`, the server *should* close the connection.

If the initial communication from the client to the server:

* Does not start with a `{`
* Does not reach a complete line within 1 megabyte of data

Then the server may send a *may* send a JSON line with an object containing `err` and
then close the connection.

#### Protocol version 1

No additional configuration keys from the client are recognized in this version of the
protocol.

Beyond the initial handshake line, the client should not send anything to the server. The
client may close the connection at any time.

The server sends JSON lines to the client. This lines are the same as specified for the
JSON lines file format.

## Checking if logging is active

Call `Log::Timeline.has-output` to see if some kind of logging output is set up in
this process, This is useful for avoiding introducing logging if it will never take
place.
