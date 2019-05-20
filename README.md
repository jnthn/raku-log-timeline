# Log::Timeline

When building an application with many ongoing, potentially overlapping,
tasks, we may find ourselves wishing to observe what is going on inside of
that application. The `Log::Timeline` module provides a means to do that.

## Key features

* Log tasks with start and end times, as well as different phases
* Log individual events
* Include data with the logged tasks and events
* Have data logged to a file, or exposed over a socket
* Turn on/off what is logged at runtime (socket mode only)
* Introspect what tasks and events a given distribution can log
* Supported by [Cro](https://cro.services/), to offer insight into client
  and server request processing pipelines
* When running on MoarVM, get access to a whole range of VM-level tasks and
  events too, such as GC runs, thread spawns, file open/close, process
  spawning, optimization, etc.
* Visualize timelines in [Comma](https://commaide.com/)

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
`provides` section of the `META6.json`. The module name's final component should be
`LogTimelineSchema`. For example, `Cro::HTTP` provides `Cro::HTTP::LogTimelineSchema`.
You may provide more than one of these per distribution.

Every task or event has a 3-part name:

* **Module** - for example, `Cro HTTP`
* **Category** - for example, `Client` and `Server`
* **Name** - for example, `HTTP Request`



## Enabling logging




