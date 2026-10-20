#import "DFZAXSource.h"

#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

// Private but long-standing (Hammerspoon relies on it too): the only way to map
// an AX window element to the CGWindowID that dfzf uses as con_id.
extern AXError _AXUIElementGetWindow(AXUIElementRef element, CGWindowID *windowId);

// Bounds every AX call, hence how long a hung app can hold its own queue.
static const float kMessagingTimeout = 1.0f;
// Apps that never answer must not hold back the recency seeding forever.
static const NSTimeInterval kScanTimeout = 3.0;
// A freshly launched app rejects observers until its AX server is up.
static const int kSetupAttempts = 10;
static const NSTimeInterval kSetupRetryDelay = 0.5;

@interface DFZAXApp : NSObject
@property (nonatomic) pid_t pid;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic) AXUIElementRef element;
@property (nonatomic) AXObserverRef observer;
// Window id -> AX element; only touched on `queue`.
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id> *windows;
@end

@implementation DFZAXApp
- (void)dealloc {
    if (_observer) {
        CFRelease(_observer);
    }
    if (_element) {
        CFRelease(_element);
    }
}
@end

static id copyAttribute(AXUIElementRef element, CFStringRef attribute) {
    CFTypeRef value = NULL;
    if (AXUIElementCopyAttributeValue(element, attribute, &value) != kAXErrorSuccess) {
        return nil;
    }
    return CFBridgingRelease(value);
}

static NSRect flipped(NSRect rect, CGFloat primaryHeight) {
    rect.origin.y = primaryHeight - rect.origin.y - rect.size.height;
    return rect;
}

static __weak id sActiveSource;

@interface DFZAXSource ()
- (void)observer:(AXObserverRef)observer
    notification:(NSString *)notification
         element:(id)element
        windowId:(DFZWindowID)windowId;
@end

static void axCallback(AXObserverRef observer, AXUIElementRef element, CFStringRef notification, void *refcon) {
    DFZAXSource *source = sActiveSource;
    [source observer:observer
        notification:(__bridge NSString *)notification
             element:(__bridge id)element
            windowId:(DFZWindowID)(uintptr_t)refcon];
}

@implementation DFZAXSource {
    __weak id<DFZWindowSourceDelegate> _delegate;
    // Guarded by @synchronized(self).
    BOOL _running;
    BOOL _scanReported;
    pid_t _frontmostPid;
    NSMutableDictionary<NSNumber *, DFZAXApp *> *_apps;
    NSMutableDictionary<NSNumber *, DFZAXApp *> *_windowApps;
    NSArray<DFZScreenInfo *> *_screens;

    CFRunLoopRef _axRunLoop;
    dispatch_queue_t _controlQueue;
    NSOperationQueue *_notificationQueue;
    NSMutableArray *_workspaceTokens;
    id _screenToken;
}

- (instancetype)init {
    if ((self = [super init])) {
        _apps = [NSMutableDictionary dictionary];
        _windowApps = [NSMutableDictionary dictionary];
        _screens = @[];
        _workspaceTokens = [NSMutableArray array];
        _controlQueue = dispatch_queue_create("dfzf.ax.control", DISPATCH_QUEUE_SERIAL);
        _notificationQueue = [NSOperationQueue new];
        _notificationQueue.underlyingQueue = _controlQueue;
    }
    return self;
}

- (void)dealloc {
    [self stop];
    if (_axRunLoop) {
        CFRelease(_axRunLoop);
    }
}

#pragma mark - Lifecycle

- (BOOL)startWithDelegate:(id<DFZWindowSourceDelegate>)delegate error:(NSString **)error {
    if (!AXIsProcessTrusted()) {
        if (error) {
            *error = @"dfzf: Hammerspoon lacks the Accessibility permission";
        }
        return NO;
    }
    _delegate = delegate;
    sActiveSource = self;
    @synchronized(self) {
        _running = YES;
        _scanReported = NO;
    }
    [self startRunLoopThread];
    [self refreshScreens];

    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    @synchronized(self) {
        _frontmostPid = workspace.frontmostApplication.processIdentifier;
    }
    NSNotificationCenter *center = workspace.notificationCenter;
    __weak DFZAXSource *weakSelf = self;
    [_workspaceTokens addObject:[center addObserverForName:NSWorkspaceDidLaunchApplicationNotification
                                                    object:nil
                                                     queue:_notificationQueue
                                                usingBlock:^(NSNotification *note) {
                                                    [weakSelf addApp:note.userInfo[NSWorkspaceApplicationKey] group:nil];
                                                }]];
    [_workspaceTokens addObject:[center addObserverForName:NSWorkspaceDidTerminateApplicationNotification
                                                    object:nil
                                                     queue:_notificationQueue
                                                usingBlock:^(NSNotification *note) {
                                                    [weakSelf removeApp:note.userInfo[NSWorkspaceApplicationKey]];
                                                }]];
    [_workspaceTokens addObject:[center addObserverForName:NSWorkspaceDidActivateApplicationNotification
                                                    object:nil
                                                     queue:_notificationQueue
                                                usingBlock:^(NSNotification *note) {
                                                    [weakSelf activateApp:note.userInfo[NSWorkspaceApplicationKey]];
                                                }]];
    // NSScreen is main-thread only: cache the frames there for the other queues.
    _screenToken = [[NSNotificationCenter defaultCenter]
        addObserverForName:NSApplicationDidChangeScreenParametersNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
                    (void)note;
                    [weakSelf refreshScreens];
                }];

    dispatch_group_t scan = dispatch_group_create();
    for (NSRunningApplication *app in workspace.runningApplications) {
        [self addApp:app group:scan];
    }
    dispatch_group_notify(scan, _controlQueue, ^{
        [weakSelf finishScan];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kScanTimeout * NSEC_PER_SEC)), _controlQueue, ^{
        [weakSelf finishScan];
    });
    return YES;
}

// AX observers deliver their callbacks on a run loop: a dedicated thread keeps
// them off the main thread, which Lua may hold for a long time.
- (void)startRunLoopThread {
    if (_axRunLoop) {
        return;
    }
    dispatch_semaphore_t ready = dispatch_semaphore_create(0);
    __block CFRunLoopRef runLoop = NULL;
    NSThread *thread = [[NSThread alloc] initWithBlock:^{
        @autoreleasepool {
            runLoop = (CFRunLoopRef)CFRetain(CFRunLoopGetCurrent());
            CFRunLoopSourceContext context = {0};
            CFRunLoopSourceRef keepAlive = CFRunLoopSourceCreate(NULL, 0, &context);
            CFRunLoopAddSource(runLoop, keepAlive, kCFRunLoopDefaultMode);
            dispatch_semaphore_signal(ready);
            CFRunLoopRun();
            CFRunLoopRemoveSource(runLoop, keepAlive, kCFRunLoopDefaultMode);
            CFRelease(keepAlive);
        }
    }];
    thread.name = @"dfzf.ax.observers";
    [thread start];
    dispatch_semaphore_wait(ready, DISPATCH_TIME_FOREVER);
    _axRunLoop = runLoop;
}

- (void)stop {
    NSArray<DFZAXApp *> *apps;
    @synchronized(self) {
        if (!_running) {
            return;
        }
        _running = NO;
        apps = _apps.allValues;
        [_apps removeAllObjects];
        [_windowApps removeAllObjects];
    }
    NSNotificationCenter *center = [NSWorkspace sharedWorkspace].notificationCenter;
    for (id token in _workspaceTokens) {
        [center removeObserver:token];
    }
    [_workspaceTokens removeAllObjects];
    if (_screenToken) {
        [[NSNotificationCenter defaultCenter] removeObserver:_screenToken];
        _screenToken = nil;
    }
    for (DFZAXApp *app in apps) {
        [self detachObserver:app];
    }
    // The run loop stays referenced until dealloc: set-ups still in flight on
    // app queues may add their observer source to it after this point.
    if (_axRunLoop) {
        CFRunLoopStop(_axRunLoop);
    }
    _delegate = nil;
    if (sActiveSource == self) {
        sActiveSource = nil;
    }
}

- (void)detachObserver:(DFZAXApp *)app {
    if (app.observer && _axRunLoop) {
        CFRunLoopRemoveSource(_axRunLoop, AXObserverGetRunLoopSource(app.observer), kCFRunLoopDefaultMode);
    }
}

- (void)finishScan {
    @synchronized(self) {
        if (_scanReported || !_running) {
            return;
        }
        _scanReported = YES;
    }
    NSMutableArray<NSNumber *> *frontToBack = [NSMutableArray array];
    NSArray *windows = CFBridgingRelease(CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
    for (NSDictionary *window in windows) {
        // Layer 0 holds the regular app windows; menu bar, dock, etc. sit above.
        if ([window[(__bridge id)kCGWindowLayer] intValue] == 0) {
            [frontToBack addObject:window[(__bridge id)kCGWindowNumber]];
        }
    }
    [_delegate windowSourceDidFinishInitialScan:frontToBack];
}

#pragma mark - Apps

- (pid_t)frontmostPid {
    @synchronized(self) {
        return _frontmostPid;
    }
}

- (BOOL)isTracking:(DFZAXApp *)app {
    @synchronized(self) {
        return _running && _apps[@(app.pid)] == app;
    }
}

- (void)addApp:(NSRunningApplication *)running group:(dispatch_group_t)group {
    // Only regular apps own user-facing windows; skipping the others keeps
    // helper processes (WebKit content, agents) out of the observer set.
    if (!running || running.activationPolicy != NSApplicationActivationPolicyRegular) {
        return;
    }
    DFZAXApp *app = [DFZAXApp new];
    app.pid = running.processIdentifier;
    app.name = running.localizedName ?: @"";
    app.windows = [NSMutableDictionary dictionary];
    NSString *label = [NSString stringWithFormat:@"dfzf.ax.app.%d", app.pid];
    app.queue = dispatch_queue_create(label.UTF8String, DISPATCH_QUEUE_SERIAL);
    @synchronized(self) {
        if (!_running || _apps[@(app.pid)]) {
            return;
        }
        _apps[@(app.pid)] = app;
    }
    if (group) {
        dispatch_group_enter(group);
    }
    dispatch_async(app.queue, ^{
        [self setUpApp:app attempt:0 group:group];
    });
}

- (void)setUpApp:(DFZAXApp *)app attempt:(int)attempt group:(dispatch_group_t)group {
    if (![self isTracking:app]) {
        if (group) {
            dispatch_group_leave(group);
        }
        return;
    }
    if (!app.element) {
        app.element = AXUIElementCreateApplication(app.pid);
        AXUIElementSetMessagingTimeout(app.element, kMessagingTimeout);
    }
    AXObserverRef observer = NULL;
    AXError status = AXObserverCreate(app.pid, axCallback, &observer);
    if (status == kAXErrorSuccess) {
        status = AXObserverAddNotification(observer, app.element, kAXWindowCreatedNotification, NULL);
    }
    if (status != kAXErrorSuccess) {
        if (observer) {
            CFRelease(observer);
        }
        if (attempt + 1 < kSetupAttempts) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSetupRetryDelay * NSEC_PER_SEC)), app.queue, ^{
                [self setUpApp:app attempt:attempt + 1 group:group];
            });
        } else if (group) {
            dispatch_group_leave(group);
        }
        return;
    }
    AXObserverAddNotification(observer, app.element, kAXFocusedWindowChangedNotification, NULL);
    app.observer = observer;
    CFRunLoopAddSource(_axRunLoop, AXObserverGetRunLoopSource(observer), kCFRunLoopDefaultMode);
    CFRunLoopWakeUp(_axRunLoop);

    NSArray *windows = copyAttribute(app.element, kAXWindowsAttribute);
    for (id window in windows) {
        [self registerWindow:window app:app event:DFZWindowEventScanned];
    }
    if (app.pid == [self frontmostPid]) {
        [self reportFocusedWindowOf:app];
    }
    if (group) {
        dispatch_group_leave(group);
    }
}

- (void)removeApp:(NSRunningApplication *)running {
    DFZAXApp *app;
    @synchronized(self) {
        app = _apps[@(running.processIdentifier)];
        [_apps removeObjectForKey:@(running.processIdentifier)];
    }
    if (!app) {
        return;
    }
    [self detachObserver:app];
    dispatch_async(app.queue, ^{
        for (NSNumber *windowId in app.windows.allKeys) {
            [self forgetWindow:windowId.unsignedIntValue app:app];
        }
    });
}

- (void)activateApp:(NSRunningApplication *)running {
    if (!running) {
        return;
    }
    DFZAXApp *app;
    @synchronized(self) {
        _frontmostPid = running.processIdentifier;
        app = _apps[@(running.processIdentifier)];
    }
    if (!app) {
        // Its set-up reports the focused window since it is now frontmost.
        [self addApp:running group:nil];
        return;
    }
    dispatch_async(app.queue, ^{
        [self reportFocusedWindowOf:app];
    });
}

#pragma mark - Windows (on the app queue)

- (void)reportFocusedWindowOf:(DFZAXApp *)app {
    id window = copyAttribute(app.element, kAXFocusedWindowAttribute);
    if (window) {
        [self focusElement:window app:app];
    }
}

- (void)focusElement:(id)element app:(DFZAXApp *)app {
    CGWindowID windowId = 0;
    if (_AXUIElementGetWindow((__bridge AXUIElementRef)element, &windowId) != kAXErrorSuccess || windowId == 0) {
        return;
    }
    if (!app.windows[@(windowId)]) {
        // Windows of other Spaces are missing from the initial AXWindows list.
        [self registerWindow:element app:app event:DFZWindowEventScanned];
    }
    // Background apps also move their own focus: only the frontmost one counts.
    if (app.pid == [self frontmostPid]) {
        [_delegate windowSourceDidFocusWindow:windowId];
    }
}

- (void)registerWindow:(id)element app:(DFZAXApp *)app event:(DFZWindowEvent)event {
    AXUIElementRef ref = (__bridge AXUIElementRef)element;
    CGWindowID windowId = 0;
    if (_AXUIElementGetWindow(ref, &windowId) != kAXErrorSuccess || windowId == 0) {
        return;
    }
    NSNumber *key = @(windowId);
    if (app.windows[key]) {
        [self reportWindow:windowId app:app event:DFZWindowEventChanged];
        return;
    }
    AXUIElementSetMessagingTimeout(ref, kMessagingTimeout);
    app.windows[key] = element;
    @synchronized(self) {
        _windowApps[key] = app;
    }
    // The window id rides in the refcon: a destroyed element can no longer tell it.
    void *refcon = (void *)(uintptr_t)windowId;
    AXObserverAddNotification(app.observer, ref, kAXTitleChangedNotification, refcon);
    AXObserverAddNotification(app.observer, ref, kAXWindowMiniaturizedNotification, refcon);
    AXObserverAddNotification(app.observer, ref, kAXWindowDeminiaturizedNotification, refcon);
    AXObserverAddNotification(app.observer, ref, kAXUIElementDestroyedNotification, refcon);
    [self reportWindow:windowId app:app event:event];
}

- (void)reportWindow:(DFZWindowID)windowId app:(DFZAXApp *)app event:(DFZWindowEvent)event {
    AXUIElementRef element = (__bridge AXUIElementRef)app.windows[@(windowId)];
    if (!element) {
        return;
    }
    DFZWindowInfo *info = [DFZWindowInfo new];
    info.windowId = windowId;
    info.pid = app.pid;
    info.appName = app.name;
    NSString *title = copyAttribute(element, kAXTitleAttribute);
    info.title = [title isKindOfClass:[NSString class]] ? title : @"";
    NSString *subrole = copyAttribute(element, kAXSubroleAttribute);
    info.standard = [subrole isKindOfClass:[NSString class]]
        && [subrole isEqualToString:(__bridge NSString *)kAXStandardWindowSubrole];
    NSNumber *minimized = copyAttribute(element, kAXMinimizedAttribute);
    info.minimized = [minimized isKindOfClass:[NSNumber class]] && minimized.boolValue;
    [_delegate windowSourceDidUpdateWindow:info event:event];
}

- (void)forgetWindow:(DFZWindowID)windowId app:(DFZAXApp *)app {
    [app.windows removeObjectForKey:@(windowId)];
    @synchronized(self) {
        if (_windowApps[@(windowId)] == app) {
            [_windowApps removeObjectForKey:@(windowId)];
        }
    }
    [_delegate windowSourceDidRemoveWindow:windowId];
}

// AX run loop thread: hop to the app queue before any AX call, which may block.
- (void)observer:(AXObserverRef)observer
    notification:(NSString *)notification
         element:(id)element
        windowId:(DFZWindowID)windowId {
    DFZAXApp *app = nil;
    @synchronized(self) {
        for (DFZAXApp *candidate in _apps.allValues) {
            if (candidate.observer == observer) {
                app = candidate;
                break;
            }
        }
    }
    if (!app) {
        return;
    }
    NSString *name = [notification copy];
    dispatch_async(app.queue, ^{
        if ([name isEqualToString:(__bridge NSString *)kAXWindowCreatedNotification]) {
            [self registerWindow:element app:app event:DFZWindowEventCreated];
        } else if ([name isEqualToString:(__bridge NSString *)kAXFocusedWindowChangedNotification]) {
            [self focusElement:element app:app];
        } else if ([name isEqualToString:(__bridge NSString *)kAXTitleChangedNotification]) {
            [self reportWindow:windowId app:app event:DFZWindowEventTitleChanged];
        } else if ([name isEqualToString:(__bridge NSString *)kAXUIElementDestroyedNotification]) {
            if (app.windows[@(windowId)]) {
                [self forgetWindow:windowId app:app];
            }
        } else {
            [self reportWindow:windowId app:app event:DFZWindowEventChanged];
        }
    });
}

#pragma mark - DFZWindowSource

- (nullable dispatch_queue_t)queueForWindow:(DFZWindowID)windowId {
    @synchronized(self) {
        return _windowApps[@(windowId)].queue;
    }
}

- (AXUIElementRef)elementOf:(DFZWindowID)windowId app:(DFZAXApp **)appOut {
    DFZAXApp *app;
    @synchronized(self) {
        app = _windowApps[@(windowId)];
    }
    if (appOut) {
        *appOut = app;
    }
    return (__bridge AXUIElementRef)app.windows[@(windowId)];
}

- (void)focusWindow:(DFZWindowID)windowId {
    DFZAXApp *app = nil;
    AXUIElementRef element = [self elementOf:windowId app:&app];
    if (!element) {
        return;
    }
    AXUIElementSetAttributeValue(element, kAXMainAttribute, kCFBooleanTrue);
    // Same as hs.window:focus(): front window only, regardless of the
    // cooperative activation rules NSRunningApplication enforces.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    ProcessSerialNumber psn;
    if (GetProcessForPID(app.pid, &psn) == noErr) {
        SetFrontProcessWithOptions(&psn, kSetFrontProcessFrontWindowOnly);
    }
#pragma clang diagnostic pop
}

- (void)closeWindow:(DFZWindowID)windowId {
    AXUIElementRef element = [self elementOf:windowId app:NULL];
    if (!element) {
        return;
    }
    id button = copyAttribute(element, kAXCloseButtonAttribute);
    if (button) {
        AXUIElementPerformAction((__bridge AXUIElementRef)button, kAXPressAction);
    }
}

- (void)setWindow:(DFZWindowID)windowId minimized:(BOOL)minimized {
    AXUIElementRef element = [self elementOf:windowId app:NULL];
    if (element) {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute, minimized ? kCFBooleanTrue : kCFBooleanFalse);
    }
}

- (BOOL)getFrame:(NSRect *)frame ofWindow:(DFZWindowID)windowId {
    AXUIElementRef element = [self elementOf:windowId app:NULL];
    if (!element) {
        return NO;
    }
    id position = copyAttribute(element, kAXPositionAttribute);
    id size = copyAttribute(element, kAXSizeAttribute);
    CGPoint point;
    CGSize extent;
    if (!position || !size || !AXValueGetValue((__bridge AXValueRef)position, kAXValueCGPointType, &point)
        || !AXValueGetValue((__bridge AXValueRef)size, kAXValueCGSizeType, &extent)) {
        return NO;
    }
    *frame = NSMakeRect(point.x, point.y, extent.width, extent.height);
    return YES;
}

- (void)setFrame:(NSRect)frame ofWindow:(DFZWindowID)windowId {
    DFZAXApp *app = nil;
    AXUIElementRef element = [self elementOf:windowId app:&app];
    if (!element) {
        return;
    }
    // Like hs.window:setFrame(): AXEnhancedUserInterface (set by assistive
    // apps) animates and breaks frame changes, so lift it meanwhile.
    CFStringRef enhancedUI = CFSTR("AXEnhancedUserInterface");
    NSNumber *enhanced = copyAttribute(app.element, enhancedUI);
    BOOL hadEnhancedUI = [enhanced isKindOfClass:[NSNumber class]] && enhanced.boolValue;
    if (hadEnhancedUI) {
        AXUIElementSetAttributeValue(app.element, enhancedUI, kCFBooleanFalse);
    }
    CGPoint point = frame.origin;
    CGSize extent = frame.size;
    AXValueRef position = AXValueCreate(kAXValueCGPointType, &point);
    AXValueRef size = AXValueCreate(kAXValueCGSizeType, &extent);
    // Size, position, size again: the first resize lets the window fit on a
    // smaller target display, the last one applies the size there.
    AXUIElementSetAttributeValue(element, kAXSizeAttribute, size);
    AXUIElementSetAttributeValue(element, kAXPositionAttribute, position);
    AXUIElementSetAttributeValue(element, kAXSizeAttribute, size);
    CFRelease(position);
    CFRelease(size);
    if (hadEnhancedUI) {
        AXUIElementSetAttributeValue(app.element, enhancedUI, kCFBooleanTrue);
    }
}

- (NSArray<DFZScreenInfo *> *)screens {
    @synchronized(self) {
        return _screens;
    }
}

- (void)refreshScreens {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshScreens];
        });
        return;
    }
    NSArray<NSScreen *> *screens = [NSScreen screens];
    CGFloat primaryHeight = screens.firstObject.frame.size.height;
    NSMutableArray<DFZScreenInfo *> *infos = [NSMutableArray array];
    for (NSScreen *screen in screens) {
        DFZScreenInfo *info = [DFZScreenInfo new];
        info.name = screen.localizedName ?: @"screen";
        info.fullFrame = flipped(screen.frame, primaryHeight);
        info.frame = flipped(screen.visibleFrame, primaryHeight);
        [infos addObject:info];
    }
    @synchronized(self) {
        _screens = [infos copy];
    }
}

@end
