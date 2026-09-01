from std.runtime import initialize_runtime


struct LifecycleValue[O: MutOrigin](Copyable):
    var event_total: Pointer[Int64, Self.O]

    def __init__(out self, ref[Self.O] event_total: Int64):
        self.event_total = Pointer(to=event_total)
        self.event_total[] += 1

    def __init__(out self, *, copy: Self):
        self.event_total = copy.event_total
        self.event_total[] += 10

    def __init__(out self, *, deinit move: Self):
        self.event_total = move.event_total
        self.event_total[] += 100

    def __deinit__(deinit self):
        self.event_total[] += 1000


def exercise_lifecycle(mut event_total: Int64):
    var original = LifecycleValue(event_total)
    var copied = original.copy()
    var moved = copied^
    _ = moved^


@export("mojo_ios_conformance_ownership")
def mojo_ios_conformance_ownership() abi("C") -> Int64:
    initialize_runtime()
    var event_total: Int64 = 0
    exercise_lifecycle(event_total)
    return event_total
