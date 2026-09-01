from max.runtime.tracing import Trace, TraceLevel
from std.runtime import initialize_runtime


@export("mojo_ios_unsupported_asyncrt_time_trace")
def mojo_ios_unsupported_asyncrt_time_trace() abi("C") -> Int64:
    initialize_runtime()
    try:
        with Trace[TraceLevel.ALWAYS]("unsupported-ios-time-trace"):
            return 42
    except:
        return -1
