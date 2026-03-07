#include "android_helper.h"

void call_source_process(android_app* state, android_poll_source* s) {
    // Delegating member function calls in C++
    s->process(state, s);
}
