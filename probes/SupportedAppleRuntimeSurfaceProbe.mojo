from std.io import open
from std.os import getenv, listdir, stat
from std.pwd import getpwuid
from std.runtime import initialize_runtime
from std.sys import num_logical_cores, num_performance_cores, num_physical_cores
from std.time import perf_counter_ns
from std.utils import BlockingSpinLock


@export("mojo_apple_runtime_lock_probe")
def mojo_apple_runtime_lock_probe() abi("C") -> Int64:
    initialize_runtime()
    var lock = BlockingSpinLock()
    lock.lock(1)
    _ = lock.unlock(1)
    return 1


@export("mojo_apple_runtime_core_count_probe")
def mojo_apple_runtime_core_count_probe() abi("C") -> Int64:
    return Int64(
        num_logical_cores()
        + num_physical_cores()
        + num_performance_cores()
    )


@export("mojo_apple_runtime_password_database_probe")
def mojo_apple_runtime_password_database_probe() abi("C") -> Int64:
    try:
        return Int64(getpwuid(0).pw_uid)
    except:
        return -1


@export("mojo_apple_runtime_file_probe")
def mojo_apple_runtime_file_probe() abi("C") -> Int64:
    try:
        with open("/dev/null", "r") as file:
            return Int64(file.read().byte_length())
    except:
        return -1


@export("mojo_apple_runtime_filesystem_metadata_probe")
def mojo_apple_runtime_filesystem_metadata_probe() abi("C") -> Int64:
    try:
        return Int64(stat("/").st_mode) + Int64(len(listdir("/")))
    except:
        return -1


@export("mojo_apple_runtime_clock_probe")
def mojo_apple_runtime_clock_probe() abi("C") -> Int64:
    return Int64(perf_counter_ns())


@export("mojo_apple_runtime_environment_probe")
def mojo_apple_runtime_environment_probe() abi("C") -> Int64:
    return Int64(getenv("PATH").byte_length())
