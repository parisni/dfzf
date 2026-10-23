#import "DFZController.h"

@implementation DFZConfig
- (instancetype)init {
    if ((self = [super init])) {
        _identityTitles = [NSSet set];
        _popupTitles = [NSSet set];
        _floatingTitles = [NSSet set];
        _popupRatio = 0.65;
        _maximize = YES;
        _actionTimeout = 2.0;
    }
    return self;
}
@end

static BOOL windowIdFrom(id value, DFZWindowID *windowId) {
    if (![value isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    *windowId = [value unsignedIntValue];
    return YES;
}

static NSArray<NSNumber *> *idListFrom(id value) {
    if (![value isKindOfClass:[NSArray class]]) {
        return nil;
    }
    for (id item in value) {
        if (![item isKindOfClass:[NSNumber class]]) {
            return nil;
        }
    }
    return value;
}

static NSString *stringFrom(id value) {
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static BOOL numberFrom(id value, double *number) {
    if (![value isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    *number = [value doubleValue];
    return YES;
}

static NSString *noWindow(id windowId) {
    return [NSString stringWithFormat:@"dfzf: no window with id %@", windowId ?: @"nil"];
}

@implementation DFZController {
    id<DFZWindowSource> _source;
    DFZConfig *_config;
    DFZState *_state;
    dispatch_queue_t _stateQueue;
}

- (instancetype)initWithSource:(id<DFZWindowSource>)source config:(DFZConfig *)config {
    if ((self = [super init])) {
        _source = source;
        _config = config;
        _state = [DFZState new];
        _state.identityTitles = config.identityTitles;
        _stateQueue = dispatch_queue_create("dfzf.state", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)start:(NSString **)error {
    return [_source startWithDelegate:self error:error];
}

- (void)stop {
    [_source stop];
}

- (void)withState:(void (^)(DFZState *state))block {
    dispatch_sync(_stateQueue, ^{
        block(self->_state);
    });
}

#pragma mark - Window source events

- (void)windowSourceDidUpdateWindow:(DFZWindowInfo *)info event:(DFZWindowEvent)event {
    dispatch_async(_stateQueue, ^{
        [self->_state upsertWindow:info];
    });
    BOOL place = event == DFZWindowEventCreated
        || (event == DFZWindowEventTitleChanged && [_config.popupTitles containsObject:info.title]);
    if (place && info.standard) {
        [self place:info];
    }
}

- (void)windowSourceDidRemoveWindow:(DFZWindowID)windowId {
    dispatch_async(_stateQueue, ^{
        [self->_state removeWindow:windowId];
    });
}

- (void)windowSourceDidFocusWindow:(DFZWindowID)windowId {
    dispatch_async(_stateQueue, ^{
        [self->_state focusWindow:windowId];
    });
}

- (void)windowSourceDidFinishInitialScan:(NSArray<NSNumber *> *)frontToBack {
    dispatch_async(_stateQueue, ^{
        // Seed recency from the z-order so the very first switch already
        // offers the previous window.
        [self->_state seedRecency:frontToBack];
        self->_state.scanComplete = YES;
    });
}

#pragma mark - Placement

- (DFZScreenInfo *)screenForFrame:(NSRect)frame {
    NSArray<DFZScreenInfo *> *screens = [_source screens];
    DFZScreenInfo *best = screens.firstObject;
    CGFloat bestArea = 0;
    for (DFZScreenInfo *screen in screens) {
        NSRect overlap = NSIntersectionRect(frame, screen.fullFrame);
        CGFloat area = overlap.size.width * overlap.size.height;
        if (area > bestArea) {
            best = screen;
            bestArea = area;
        }
    }
    return best;
}

// Must run on the window's app queue.
- (DFZScreenInfo *)screenOfWindow:(DFZWindowID)windowId {
    NSRect frame = NSZeroRect;
    if ([_source getFrame:&frame ofWindow:windowId]) {
        return [self screenForFrame:frame];
    }
    return [_source screens].firstObject;
}

// No tiling on macOS: dfzf popups are centered, other windows maximized
// unless their own scripts size them (floatingTitles).
- (void)place:(DFZWindowInfo *)info {
    dispatch_queue_t queue = [_source queueForWindow:info.windowId];
    if (!queue) {
        return;
    }
    DFZWindowID windowId = info.windowId;
    NSString *title = info.title;
    dispatch_async(queue, ^{
        DFZScreenInfo *screen = [self screenOfWindow:windowId];
        if (!screen) {
            return;
        }
        NSRect area = screen.frame;
        if ([self->_config.popupTitles containsObject:title]) {
            double ratio = self->_config.popupRatio;
            NSRect frame = NSMakeRect(area.origin.x + area.size.width * (1 - ratio) / 2,
                                      area.origin.y + area.size.height * (1 - ratio) / 2,
                                      area.size.width * ratio, area.size.height * ratio);
            [self->_source setFrame:frame ofWindow:windowId];
            [self->_source focusWindow:windowId];
            [self closePopupsOlderThan:windowId];
        } else if (self->_config.maximize && ![self->_config.floatingTitles containsObject:title]) {
            [self->_source setFrame:area ofWindow:windowId];
        }
    });
}

// One dfzf popup at a time, the newest wins: macOS window ids only grow, so this
// needs no focus (unlike sway's dfzf-kill-bro) and a replayed event on an older
// popup never closes a newer one.
- (void)closePopupsOlderThan:(DFZWindowID)windowId {
    NSMutableArray<NSNumber *> *older = [NSMutableArray array];
    [self withState:^(DFZState *state) {
        for (DFZWindowInfo *info in [state windows]) {
            if (info.windowId < windowId && [self->_config.popupTitles containsObject:info.title]) {
                [older addObject:@(info.windowId)];
            }
        }
    }];
    for (NSNumber *item in older) {
        DFZWindowID target = item.unsignedIntValue;
        dispatch_queue_t queue = [_source queueForWindow:target];
        if (queue) {
            dispatch_async(queue, ^{
                [self->_source closeWindow:target];
            });
        }
    }
}

#pragma mark - Requests

// Runs a window action on its app queue, giving up at the deadline so a hung
// app fails the request instead of blocking the caller forever.
- (BOOL)onWindow:(DFZWindowID)windowId
        deadline:(dispatch_time_t)deadline
           error:(NSString **)error
             run:(void (^)(void))block {
    dispatch_queue_t queue = [_source queueForWindow:windowId];
    if (!queue) {
        *error = noWindow(@(windowId));
        return NO;
    }
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    dispatch_async(queue, ^{
        block();
        dispatch_semaphore_signal(done);
    });
    if (dispatch_semaphore_wait(done, deadline) != 0) {
        *error = [NSString stringWithFormat:@"dfzf: window %u did not respond within %gs", windowId,
                                            _config.actionTimeout];
        return NO;
    }
    return YES;
}

- (NSString *)handleRequest:(NSData *)request ok:(BOOL *)ok {
    NSString *raw = [[NSString alloc] initWithData:request encoding:NSUTF8StringEncoding] ?: @"";
    raw = [raw stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    id parsed = [NSJSONSerialization JSONObjectWithData:request options:0 error:NULL];
    NSDictionary *req = [parsed isKindOfClass:[NSDictionary class]] ? parsed : nil;
    NSString *op = stringFrom(req[@"op"]);
    NSString *error = nil;
    NSString *reply = op ? [self run:op request:req error:&error] : nil;
    if (!reply && !error) {
        error = [NSString stringWithFormat:@"dfzf: unknown request %@", raw];
    } else if ([error isEqualToString:@""]) {
        error = [NSString stringWithFormat:@"dfzf: invalid request %@", raw];
    }
    *ok = error == nil;
    return error ?: reply;
}

// Returns nil without error for an unknown op, nil with an empty error for
// malformed arguments; handleRequest turns both into the full message.
- (NSString *)run:(NSString *)op request:(NSDictionary *)req error:(NSString **)error {
    dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_config.actionTimeout * NSEC_PER_SEC));
    DFZWindowID windowId = 0;
    BOOL hasId = windowIdFrom(req[@"id"], &windowId);
    NSArray<NSNumber *> *ids = idListFrom(req[@"ids"]);

    if ([op isEqualToString:@"tree"]) {
        __block NSString *json;
        [self withState:^(DFZState *state) {
            json = [state treeJSON];
        }];
        return json;
    }
    if ([op isEqualToString:@"outputs"]) {
        return [self outputsWithDeadline:deadline];
    }
    if ([op isEqualToString:@"focus"] || [op isEqualToString:@"show"]) {
        if (!hasId) {
            *error = noWindow(req[@"id"]);
            return nil;
        }
        __block BOOL minimized = NO;
        [self withState:^(DFZState *state) {
            minimized = [state window:windowId].minimized;
        }];
        [self onWindow:windowId deadline:deadline error:error run:^{
            if (minimized) {
                [self->_source setWindow:windowId minimized:NO];
            }
            [self->_source focusWindow:windowId];
        }];
        return *error ? nil : @"";
    }
    if ([op isEqualToString:@"close"] || [op isEqualToString:@"hide"]) {
        if (!ids) {
            *error = @"";
            return nil;
        }
        BOOL close = [op isEqualToString:@"close"];
        for (NSNumber *item in ids) {
            DFZWindowID target = item.unsignedIntValue;
            if (close && ![_source queueForWindow:target]) {
                continue;
            }
            BOOL done = [self onWindow:target deadline:deadline error:error run:^{
                if (close) {
                    [self->_source closeWindow:target];
                } else {
                    [self->_source setWindow:target minimized:YES];
                }
            }];
            if (!done) {
                return nil;
            }
        }
        return @"";
    }
    if ([op isEqualToString:@"resize"] || [op isEqualToString:@"move"]) {
        BOOL resize = [op isEqualToString:@"resize"];
        double first = 0, second = 0;
        if (!numberFrom(req[resize ? @"w" : @"x"], &first) || !numberFrom(req[resize ? @"h" : @"y"], &second)) {
            *error = @"";
            return nil;
        }
        if (!hasId) {
            *error = noWindow(req[@"id"]);
            return nil;
        }
        __block BOOL framed = NO;
        BOOL done = [self onWindow:windowId deadline:deadline error:error run:^{
            NSRect frame = NSZeroRect;
            if (![self->_source getFrame:&frame ofWindow:windowId]) {
                return;
            }
            framed = YES;
            if (resize) {
                frame.size = NSMakeSize(first, second);
            } else {
                // sway positions are relative to the output: offset by the screen origin.
                NSPoint origin = [self screenForFrame:frame].frame.origin;
                frame.origin = NSMakePoint(origin.x + first, origin.y + second);
            }
            [self->_source setFrame:frame ofWindow:windowId];
        }];
        if (done && !framed) {
            *error = [NSString stringWithFormat:@"dfzf: cannot read the frame of window %u", windowId];
        }
        return *error ? nil : @"";
    }
    return [self runStateOp:op request:req windowId:hasId ? @(windowId) : nil ids:ids error:error];
}

- (NSString *)runStateOp:(NSString *)op
                 request:(NSDictionary *)req
                windowId:(NSNumber *)windowId
                     ids:(NSArray<NSNumber *> *)ids
                   error:(NSString **)error {
    void (^update)(DFZState *state) = nil;
    NSString *mark = stringFrom(req[@"mark"]);
    if ([op isEqualToString:@"urgent"]) {
        NSString *mode = stringFrom(req[@"mode"]);
        if (ids && mode) {
            update = ^(DFZState *state) {
                [state setUrgent:mode windows:ids];
            };
        }
    } else if ([op isEqualToString:@"mark"]) {
        BOOL add = [req[@"add"] isKindOfClass:[NSNumber class]] && [req[@"add"] boolValue];
        if (windowId && mark) {
            update = ^(DFZState *state) {
                [state setMark:mark onWindow:windowId.unsignedIntValue add:add];
            };
        }
    } else if ([op isEqualToString:@"unmark"]) {
        BOOL validIds = req[@"ids"] == nil || ids != nil;
        if (mark && validIds) {
            update = ^(DFZState *state) {
                [state unmark:mark windows:ids];
            };
        }
    } else if ([op isEqualToString:@"markToggle"]) {
        NSString *prefix = stringFrom(req[@"prefix"]);
        BOOL appendTs = [req[@"appendTs"] isKindOfClass:[NSNumber class]] && [req[@"appendTs"] boolValue];
        if (windowId && prefix) {
            update = ^(DFZState *state) {
                [state markToggle:prefix onWindow:windowId.unsignedIntValue appendTs:appendTs];
            };
        }
    } else {
        return nil;
    }
    if (!update) {
        *error = @"";
        return nil;
    }
    [self withState:update];
    return @"";
}

- (NSString *)outputsWithDeadline:(dispatch_time_t)deadline {
    __block DFZWindowID focusedId = 0;
    [self withState:^(DFZState *state) {
        focusedId = state.focusedId;
    }];
    __block DFZScreenInfo *found = nil;
    DFZScreenInfo *screen = nil;
    NSString *ignored = nil;
    // A hung focused app must not fail `outputs`: fall back to the primary screen.
    if (focusedId && [self onWindow:focusedId deadline:deadline error:&ignored run:^{
            found = [self screenOfWindow:focusedId];
        }]) {
        screen = found;
    }
    screen = screen ?: [_source screens].firstObject;
    NSRect frame = screen ? screen.frame : NSZeroRect;
    NSArray *outputs = @[ @{
        @"name" : screen.name.length ? screen.name : @"screen",
        @"focused" : @YES,
        @"rect" : @{
            @"x" : @(frame.origin.x),
            @"y" : @(frame.origin.y),
            @"width" : @(frame.size.width),
            @"height" : @(frame.size.height),
        },
    } ];
    NSData *data = [NSJSONSerialization dataWithJSONObject:outputs options:0 error:NULL];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end
