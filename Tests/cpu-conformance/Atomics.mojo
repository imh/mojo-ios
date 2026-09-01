from std.atomic import Atomic, Ordering, fence
from std.runtime import initialize_runtime


@export("mojo_ios_conformance_atomics")
def mojo_ios_conformance_atomics() abi("C") -> Int64:
    initialize_runtime()

    var value32 = Atomic[Int32](3)
    if value32.load[ordering=Ordering.RELAXED]() != 3:
        return -1
    value32.store[ordering=Ordering.RELEASE](7)
    if value32.load[ordering=Ordering.ACQUIRE]() != 7:
        return -2
    if value32.fetch_add[ordering=Ordering.ACQUIRE_RELEASE](5) != 7:
        return -3
    if value32.fetch_sub[ordering=Ordering.SEQUENTIAL](2) != 12:
        return -4

    var expected32: Int32 = 10
    if not value32.compare_exchange[
        success_ordering=Ordering.ACQUIRE_RELEASE,
        failure_ordering=Ordering.ACQUIRE,
    ](expected32, 21):
        return -5
    expected32 = 10
    if value32.compare_exchange[
        success_ordering=Ordering.SEQUENTIAL,
        failure_ordering=Ordering.ACQUIRE,
    ](expected32, 99):
        return -6
    if expected32 != 21:
        return -7

    var value64 = Atomic[Int64](40)
    value64.max[ordering=Ordering.RELAXED](42)
    value64.min[ordering=Ordering.SEQUENTIAL](41)
    fence[ordering=Ordering.ACQUIRE_RELEASE]()
    return value64.load[ordering=Ordering.SEQUENTIAL]() + 1
