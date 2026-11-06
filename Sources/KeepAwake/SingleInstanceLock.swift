import Foundation
import Darwin

/// Keep the descriptor open for the lifetime of the process. Never unlink the
/// lock file: replacing its inode would let another process acquire a new lock.
final class SingleInstanceLock {
    enum LockError: Error {
        case alreadyRunning
        case unavailable(Int32)
    }

    private let descriptor: Int32

    init(fileURL: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let fd = open(fileURL.path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw LockError.unavailable(errno) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            close(fd)
            if code == EWOULDBLOCK { throw LockError.alreadyRunning }
            throw LockError.unavailable(code)
        }
        descriptor = fd
    }

    deinit { close(descriptor) }
}
