#import "DFZServer.h"

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

static const size_t kMaxRequestBytes = 1 << 20;
// A client that stalls mid-request must not pin a worker thread forever.
static const int kClientTimeoutSeconds = 5;

@implementation DFZServer {
    NSString *_path;
    DFZRequestHandler _handler;
    dispatch_source_t _listener;
    dispatch_queue_t _workers;
}

- (instancetype)initWithPath:(NSString *)path handler:(DFZRequestHandler)handler {
    if ((self = [super init])) {
        _path = [path copy];
        _handler = [handler copy];
        // Concurrent: a request waiting on a hung app must not delay the others.
        _workers = dispatch_queue_create("dfzf.server.client", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

static NSString *posixError(NSString *what) {
    return [NSString stringWithFormat:@"dfzf: %@: %s", what, strerror(errno)];
}

- (BOOL)start:(NSString **)error {
    NSString *message = [self listen];
    if (message && error) {
        *error = message;
    }
    return message == nil;
}

- (NSString *)listen {
    struct sockaddr_un address;
    memset(&address, 0, sizeof(address));
    address.sun_family = AF_UNIX;
    const char *path = _path.fileSystemRepresentation;
    if (strlen(path) >= sizeof(address.sun_path)) {
        return [NSString stringWithFormat:@"dfzf: socket path too long: %@", _path];
    }
    strncpy(address.sun_path, path, sizeof(address.sun_path) - 1);

    NSString *directory = _path.stringByDeletingLastPathComponent;
    if (![[NSFileManager defaultManager] fileExistsAtPath:directory]) {
        NSError *mkdirError = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:directory
                                       withIntermediateDirectories:YES
                                                        attributes:@{NSFilePosixPermissions : @0700}
                                                             error:&mkdirError]) {
            return [NSString stringWithFormat:@"dfzf: cannot create %@: %@", directory,
                                              mkdirError.localizedDescription];
        }
    }
    // A previous Hammerspoon session may have left its socket behind.
    struct stat existing;
    if (lstat(path, &existing) == 0) {
        if (!S_ISSOCK(existing.st_mode)) {
            return [NSString stringWithFormat:@"dfzf: %@ exists and is not a socket", _path];
        }
        unlink(path);
    }

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        return posixError(@"socket");
    }
    if (bind(fd, (struct sockaddr *)&address, sizeof(address)) != 0 || chmod(path, 0600) != 0
        || listen(fd, 64) != 0 || fcntl(fd, F_SETFL, O_NONBLOCK) != 0) {
        NSString *message = posixError(_path);
        close(fd);
        unlink(path);
        return message;
    }

    dispatch_queue_t acceptQueue = dispatch_queue_create("dfzf.server.accept", DISPATCH_QUEUE_SERIAL);
    _listener = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)fd, 0, acceptQueue);
    DFZRequestHandler handler = _handler;
    dispatch_queue_t workers = _workers;
    dispatch_source_set_event_handler(_listener, ^{
        int client;
        while ((client = accept(fd, NULL, NULL)) >= 0) {
            dispatch_async(workers, ^{
                serveClient(client, handler);
            });
        }
    });
    dispatch_source_set_cancel_handler(_listener, ^{
        close(fd);
    });
    dispatch_resume(_listener);
    return nil;
}

static BOOL writeAll(int fd, NSData *data) {
    const char *bytes = data.bytes;
    size_t left = data.length;
    while (left > 0) {
        ssize_t written = write(fd, bytes, left);
        if (written < 0 && errno == EINTR) {
            continue;
        }
        if (written <= 0) {
            return NO;
        }
        bytes += written;
        left -= (size_t)written;
    }
    return YES;
}

static void serveClient(int fd, DFZRequestHandler handler) {
    @autoreleasepool {
        // Accepted sockets inherit O_NONBLOCK from the listener on BSD.
        fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK);
        struct timeval timeout = {kClientTimeoutSeconds, 0};
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
#ifdef SO_NOSIGPIPE
        int on = 1;
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));
#endif
        NSMutableData *request = [NSMutableData data];
        char buffer[4096];
        BOOL complete = NO, failed = NO;
        while (!complete && request.length < kMaxRequestBytes) {
            ssize_t count = read(fd, buffer, sizeof(buffer));
            if (count < 0 && errno == EINTR) {
                continue;
            }
            if (count <= 0) {
                failed = count < 0;
                break;
            }
            void *newline = memchr(buffer, '\n', (size_t)count);
            if (newline) {
                count = (char *)newline - buffer;
                complete = YES;
            }
            [request appendBytes:buffer length:(size_t)count];
        }
        // A request cut by EOF is still served: only a read error drops it.
        if (complete || (!failed && request.length > 0)) {
            BOOL ok = NO;
            NSString *reply = handler(request, &ok);
            NSString *framed = [NSString stringWithFormat:@"%@\n%@", ok ? @"ok" : @"err", reply];
            writeAll(fd, [framed dataUsingEncoding:NSUTF8StringEncoding]);
        }
        close(fd);
    }
}

- (void)stop {
    if (_listener) {
        dispatch_source_cancel(_listener);
        _listener = nil;
        unlink(_path.fileSystemRepresentation);
    }
}

- (void)dealloc {
    [self stop];
}

@end
