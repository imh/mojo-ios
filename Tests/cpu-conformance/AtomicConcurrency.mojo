from max.algorithm import parallelize
from std.atomic import Atomic, Ordering
from std.runtime import initialize_runtime, parallelism_level


@export("mojo_ios_conformance_atomic_concurrency")
def mojo_ios_conformance_atomic_concurrency() abi("C") -> Int64:
    initialize_runtime()
    if parallelism_level() < 2:
        return -1

    comptime work_items = 4096
    var counter = Atomic[Int64](0)

    def increment(index: Int) {mut counter}:
        _ = index
        _ = counter.fetch_add[ordering=Ordering.RELAXED](1)

    parallelize(increment, work_items)
    if counter.load[ordering=Ordering.ACQUIRE]() != work_items:
        return -2

    var payload: Int64 = 0
    var arrived = Atomic[Int32](0)
    var published = Atomic[Int32](0)
    var observed = Atomic[Int64](0)

    def publish_or_observe(index: Int) {
        mut payload, mut arrived, mut published, mut observed
    }:
        _ = arrived.fetch_add[ordering=Ordering.ACQUIRE_RELEASE](1)
        while arrived.load[ordering=Ordering.ACQUIRE]() != 2:
            pass

        if index == 0:
            payload = 42
            published.store[ordering=Ordering.RELEASE](1)
            return

        while published.load[ordering=Ordering.ACQUIRE]() == 0:
            pass
        observed.store[ordering=Ordering.RELAXED](payload)

    parallelize(publish_or_observe, 2, 2)
    return observed.load[ordering=Ordering.SEQUENTIAL]()
