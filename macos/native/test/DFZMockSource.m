#import "DFZMockSource.h"

DFZWindowInfo *DFZMakeWindow(DFZWindowID windowId, NSString *title, NSString *app, pid_t pid, BOOL standard) {
    DFZWindowInfo *info = [DFZWindowInfo new];
    info.windowId = windowId;
    info.title = title;
    info.appName = app;
    info.pid = pid;
    info.standard = standard;
    return info;
}

static DFZWindowInfo *withMinimized(DFZWindowInfo *info, BOOL minimized) {
    DFZWindowInfo *copy = DFZMakeWindow(info.windowId, info.title, info.appName, info.pid, info.standard);
    copy.minimized = minimized;
    return copy;
}

@implementation DFZMockWindow
@end

// Holder: dispatch queues are not Objective-C objects on every platform, so
// they cannot sit directly in a collection.
@interface DFZMockQueue : NSObject {
  @public
    dispatch_queue_t queue;
}
@end

@implementation DFZMockQueue
@end

@implementation DFZMockSource {
    __weak id<DFZWindowSourceDelegate> _delegate;
    NSMutableDictionary<NSNumber *, DFZMockWindow *> *_windows;
    NSMutableArray<NSNumber *> *_initial;
    NSMutableDictionary<NSNumber *, DFZMockQueue *> *_queues;
    NSMutableDictionary<NSNumber *, NSNumber *> *_delays;
}

- (instancetype)init {
    if ((self = [super init])) {
        _windows = [NSMutableDictionary dictionary];
        _initial = [NSMutableArray array];
        _queues = [NSMutableDictionary dictionary];
        _delays = [NSMutableDictionary dictionary];
        _frontToBack = @[];
    }
    return self;
}

- (dispatch_queue_t)queueForPid:(pid_t)pid {
    @synchronized(self) {
        DFZMockQueue *holder = _queues[@(pid)];
        if (!holder) {
            holder = [DFZMockQueue new];
            holder->queue = dispatch_queue_create("dfzf.mock.app", DISPATCH_QUEUE_SERIAL);
            _queues[@(pid)] = holder;
        }
        return holder->queue;
    }
}

- (void)addWindow:(DFZWindowID)windowId title:(NSString *)title app:(NSString *)app pid:(pid_t)pid {
    [self addWindow:DFZMakeWindow(windowId, title, app, pid, YES) event:DFZWindowEventScanned];
}

- (void)addWindow:(DFZWindowInfo *)info event:(DFZWindowEvent)event {
    DFZMockWindow *window = [DFZMockWindow new];
    window.info = info;
    window.frame = NSMakeRect(0, 0, 10, 10);
    id<DFZWindowSourceDelegate> delegate;
    @synchronized(self) {
        _windows[@(info.windowId)] = window;
        delegate = _delegate;
        if (!delegate) {
            [_initial addObject:@(info.windowId)];
            return;
        }
    }
    dispatch_async([self queueForPid:info.pid], ^{
        [delegate windowSourceDidUpdateWindow:info event:event];
    });
}

- (BOOL)startWithDelegate:(id<DFZWindowSourceDelegate>)delegate error:(NSString **)error {
    dispatch_group_t scan = dispatch_group_create();
    @synchronized(self) {
        _delegate = delegate;
        for (NSNumber *windowId in _initial) {
            DFZWindowInfo *info = _windows[windowId].info;
            dispatch_group_async(scan, [self queueForPid:info.pid], ^{
                [delegate windowSourceDidUpdateWindow:info event:DFZWindowEventScanned];
            });
        }
    }
    NSArray<NSNumber *> *order = self.frontToBack;
    dispatch_group_wait(scan, DISPATCH_TIME_FOREVER);
    [delegate windowSourceDidFinishInitialScan:order];
    return YES;
}

- (void)stop {
    @synchronized(self) {
        _delegate = nil;
    }
}

- (id<DFZWindowSourceDelegate>)delegate {
    @synchronized(self) {
        return _delegate;
    }
}

- (void)emitFocus:(DFZWindowID)windowId {
    DFZMockWindow *window = [self window:windowId];
    dispatch_async([self queueForPid:window.info.pid], ^{
        [[self delegate] windowSourceDidFocusWindow:windowId];
    });
}

- (void)emitTitleChange:(DFZWindowID)windowId {
    DFZMockWindow *window = [self window:windowId];
    dispatch_async([self queueForPid:window.info.pid], ^{
        [[self delegate] windowSourceDidUpdateWindow:window.info event:DFZWindowEventTitleChanged];
    });
}

- (void)setDelay:(NSTimeInterval)delay forPid:(pid_t)pid {
    @synchronized(self) {
        _delays[@(pid)] = @(delay);
    }
}

- (nullable DFZMockWindow *)window:(DFZWindowID)windowId {
    @synchronized(self) {
        return _windows[@(windowId)];
    }
}

- (void)flush {
    NSArray<DFZMockQueue *> *holders;
    @synchronized(self) {
        holders = _queues.allValues;
    }
    for (DFZMockQueue *holder in holders) {
        dispatch_sync(holder->queue, ^{
        });
    }
}

// Actions run on the app queue: sleeping here stalls that app only.
- (DFZMockWindow *)act:(DFZWindowID)windowId {
    DFZMockWindow *window = [self window:windowId];
    NSNumber *delay;
    @synchronized(self) {
        delay = _delays[@(window.info.pid)];
    }
    if (delay) {
        [NSThread sleepForTimeInterval:delay.doubleValue];
    }
    return window;
}

- (nullable dispatch_queue_t)queueForWindow:(DFZWindowID)windowId {
    DFZMockWindow *window = [self window:windowId];
    return window ? [self queueForPid:window.info.pid] : nil;
}

- (void)focusWindow:(DFZWindowID)windowId {
    if ([self act:windowId]) {
        self.focusedId = windowId;
        [[self delegate] windowSourceDidFocusWindow:windowId];
    }
}

- (void)closeWindow:(DFZWindowID)windowId {
    if ([self act:windowId]) {
        @synchronized(self) {
            [_windows removeObjectForKey:@(windowId)];
        }
        [[self delegate] windowSourceDidRemoveWindow:windowId];
    }
}

- (void)setWindow:(DFZWindowID)windowId minimized:(BOOL)minimized {
    DFZMockWindow *window = [self act:windowId];
    if (window) {
        window.info = withMinimized(window.info, minimized);
        [[self delegate] windowSourceDidUpdateWindow:window.info event:DFZWindowEventChanged];
    }
}

- (BOOL)getFrame:(NSRect *)frame ofWindow:(DFZWindowID)windowId {
    DFZMockWindow *window = [self act:windowId];
    if (window) {
        *frame = window.frame;
    }
    return window != nil;
}

- (void)setFrame:(NSRect)frame ofWindow:(DFZWindowID)windowId {
    DFZMockWindow *window = [self act:windowId];
    window.frame = frame;
    window.setFrameCount += 1;
}

- (NSArray<DFZScreenInfo *> *)screens {
    DFZScreenInfo *screen = [DFZScreenInfo new];
    screen.name = @"Built-in";
    screen.frame = NSMakeRect(0, 25, 1000, 800);
    screen.fullFrame = NSMakeRect(0, 0, 1000, 825);
    return @[ screen ];
}

@end
