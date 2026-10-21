#ifndef NOTCH_MEDIA_BRIDGE_H
#define NOTCH_MEDIA_BRIDGE_H

/// Streams now-playing state as JSON lines on stdout and reads commands from stdin.
/// Never returns. It is installed as a Perl XSUB, so it takes Perl's two arguments
/// (interpreter and CV) and ignores them.
///
/// Commands (one per line): play, pause, toggle, next, previous, refresh, seek <seconds>.
/// The process exits when stdin closes, so it never outlives the app.
__attribute__((visibility("default")))
void notch_media_stream(void *interpreter, void *cv);

#endif
