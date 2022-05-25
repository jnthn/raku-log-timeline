use v6.d;
unit module Log::Timeline::Raku::LogTimelineSchema;
use Log::Timeline::Model;

class FileOpen does Log::Timeline::Task['Raku', 'IO', 'File Open'] { }
class RunThread does Log::Timeline::Task['Raku', 'Concurrency', 'Thread'] { }
