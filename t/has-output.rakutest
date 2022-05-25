use Log::Timeline;
use Test;

with  %*ENV<LOG_TIMELINE_SERVER> {
    ok Log::Timeline.has-output, 'Server output configured for Log::Timeline';
} orwith  %*ENV<LOG_TIMELINE_JSON_LINES> {
    ok Log::Timeline.has-output, 'Lines output configured for Log::Timeline';
} else {
    nok Log::Timeline.has-output, 'No output configured for Log::Timeline';
}

done-testing;
