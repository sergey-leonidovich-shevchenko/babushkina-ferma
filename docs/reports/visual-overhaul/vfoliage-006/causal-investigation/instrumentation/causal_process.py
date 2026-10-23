"""Read-only Mach CPU counters for the owned QA processes; never converts missing data to zero."""

from __future__ import annotations
import ctypes as C
import os
import time


class Usage(C.Structure):
    _fields_ = [("uuid", C.c_ubyte * 16)] + [
        (name, C.c_uint64)
        for name in (
            "user",
            "system",
            "package_wakeups",
            "interrupt_wakeups",
            "pageins",
            "wired",
            "resident",
            "footprint",
            "start",
            "exit",
            "child_user",
            "child_system",
            "child_package_wakeups",
            "child_interrupt_wakeups",
            "child_pageins",
            "child_elapsed",
            "disk_read",
            "disk_write",
        )
    ]


class Timebase(C.Structure):
    _fields_ = [("numer", C.c_uint32), ("denom", C.c_uint32)]


def ticks_ns(value, numer, denom):
    if value < 0 or numer <= 0 or denom <= 0:
        raise ValueError("invalid Mach timebase/counter")
    return value * numer // denom


class Counters:
    def __init__(self):
        self.lib = C.CDLL("/usr/lib/libproc.dylib", use_errno=True)
        self.lib.proc_pid_rusage.argtypes = [C.c_int, C.c_int, C.c_void_p]
        self.lib.proc_pid_rusage.restype = C.c_int
        self.mach = C.CDLL("/usr/lib/libSystem.B.dylib", use_errno=True)
        self.mach.mach_timebase_info.argtypes = [C.POINTER(Timebase)]
        self.mach.mach_host_self.restype = C.c_uint32
        self.mach.host_statistics.argtypes = [
            C.c_uint32,
            C.c_int,
            C.c_void_p,
            C.POINTER(C.c_uint32),
        ]
        self.host = self.mach.mach_host_self()
        self.timebase = Timebase()
        if self.mach.mach_timebase_info(C.byref(self.timebase)) != 0:
            raise OSError("mach_timebase_info unavailable")

    def process(self, pid):
        start = time.monotonic_ns()
        usage = Usage()
        code = self.lib.proc_pid_rusage(pid, 2, C.byref(usage))
        end = time.monotonic_ns()
        if code != 0:
            return {
                "pid": pid,
                "query_begin_ns": start,
                "query_end_ns": end,
                "available": False,
                "errno": C.get_errno(),
            }
        numer, denom = self.timebase.numer, self.timebase.denom
        return {
            "pid": pid,
            "query_begin_ns": start,
            "query_end_ns": end,
            "available": True,
            "timebase": [numer, denom],
            "user_ticks": usage.user,
            "system_ticks": usage.system,
            "cpu_ns": ticks_ns(usage.user + usage.system, numer, denom),
            "resident_bytes": usage.resident,
            "footprint_bytes": usage.footprint,
            "pageins": usage.pageins,
            "disk_read_bytes": usage.disk_read,
            "disk_write_bytes": usage.disk_write,
        }

    def snapshot(self, processes):
        data = {
            "host_ns": time.monotonic_ns(),
            "load_average": os.getloadavg(),
            "processes": {role: self.process(pid) for role, pid in processes.items()},
        }
        ticks = (C.c_uint32 * 4)()
        count = C.c_uint32(4)
        code = self.mach.host_statistics(self.host, 3, C.byref(ticks), C.byref(count))
        data["host_cpu_ticks"] = list(ticks) if code == 0 and count.value == 4 else None
        return data


def cpu_window(begin, end, role="game"):
    first, last = begin["processes"][role], end["processes"][role]
    if not first["available"] or not last["available"]:
        return {"available": False}
    if first["pid"] != last["pid"] or first["timebase"] != last["timebase"]:
        raise ValueError("CPU identity changed")
    cpu = last["cpu_ns"] - first["cpu_ns"]
    low = last["query_begin_ns"] - first["query_end_ns"]
    high = last["query_end_ns"] - first["query_begin_ns"]
    if cpu < 0 or low <= 0:
        raise ValueError("non-monotonic CPU/wall window")
    return {
        "available": True,
        "cpu_ns": cpu,
        "wall_bounds_ns": [low, high],
        "cpu_to_wall_bounds": [cpu / high, cpu / low],
        "boundary_query_ns": [
            first["query_end_ns"] - first["query_begin_ns"],
            last["query_end_ns"] - last["query_begin_ns"],
        ],
    }
