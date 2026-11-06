import Darwin
import Foundation

/// What the kernel reports about a running process: when it started and its controlling terminal.
public struct ProcessSnapshot: Hashable, Sendable {
    public let startedAt: Date
    /// Device name of the controlling terminal, such as "ttys005". `nil` without one.
    public let tty: String?

    public init(startedAt: Date, tty: String?) {
        self.startedAt = startedAt
        self.tty = tty
    }
}

/// Reads ``ProcessSnapshot``s with `sysctl`, without launching any tool.
public enum SystemProcess {
    public static func snapshot(of id: Int32) -> ProcessSnapshot? {
        guard id > 0 else { return nil }
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, id]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0, size > 0, info.kp_proc.p_pid == id else {
            return nil
        }
        let start = info.kp_proc.p_un.__p_starttime
        let startedAt = Date(
            timeIntervalSince1970: TimeInterval(start.tv_sec) + TimeInterval(start.tv_usec) / 1_000_000)
        let device = info.kp_eproc.e_tdev
        // NODEV (-1) means no controlling terminal.
        let tty = device == -1 ? nil : devname(device, S_IFCHR).map { String(cString: $0) }
        return ProcessSnapshot(startedAt: startedAt, tty: tty)
    }
}
