#import "DFZController.h"

@implementation DFZConfig
- (instancetype)init {
    if ((self = [super init])) {
        _identityTitles = [NSSet set];
        _popupTitles = [NSSet set];
        _floatingTitles = [NSSet set];
        _centeredTitles = [NSSet set];
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

static BOOL isCriteriaSpace(unichar character) {
    return [NSCharacterSet.whitespaceCharacterSet characterIsMember:character];
}

// Same syntax and keys as dfzf-hs-msg: [key="value with \"escapes\"" key=bareword].
// Only \" is unescaped: any other backslash belongs to the regex.
static NSArray<NSArray<NSString *> *> *parseCriteria(NSString *text, NSString **error) {
    NSString *body = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSUInteger length = body.length;
    BOOL valid = length >= 2 && [body characterAtIndex:0] == '[' && [body characterAtIndex:length - 1] == ']';
    NSUInteger index = 1;
    NSUInteger end = length - 1;
    NSSet<NSString *> *supported = [NSSet setWithArray:@[ @"con_id", @"app_id", @"class", @"title", @"con_mark" ]];
    NSMutableArray<NSArray<NSString *> *> *pairs = [NSMutableArray array];
    while (valid) {
        while (index < end && isCriteriaSpace([body characterAtIndex:index])) {
            index++;
        }
        if (index >= end) {
            break;
        }
        NSUInteger start = index;
        while (index < end && (([body characterAtIndex:index] >= 'a' && [body characterAtIndex:index] <= 'z')
                                  || [body characterAtIndex:index] == '_')) {
            index++;
        }
        NSString *key = [body substringWithRange:NSMakeRange(start, index - start)];
        if (!key.length || index >= end || [body characterAtIndex:index] != '=') {
            valid = NO;
            break;
        }
        index++;
        NSMutableString *value = [NSMutableString string];
        if (index < end && [body characterAtIndex:index] == '"') {
            index++;
            valid = NO;
            while (index < end) {
                unichar character = [body characterAtIndex:index++];
                if (character == '"') {
                    valid = YES;
                    break;
                }
                if (character == '\\' && index < end) {
                    unichar escaped = [body characterAtIndex:index++];
                    if (escaped != '"') {
                        [value appendString:@"\\"];
                    }
                    character = escaped;
                }
                [value appendFormat:@"%C", character];
            }
        } else {
            start = index;
            while (index < end && !isCriteriaSpace([body characterAtIndex:index])) {
                index++;
            }
            [value appendString:[body substringWithRange:NSMakeRange(start, index - start)]];
            valid = value.length > 0;
        }
        if (valid && ![supported containsObject:key]) {
            *error = [NSString stringWithFormat:@"dfzf: unsupported on macOS: criteria key '%@'", key];
            return nil;
        }
        if (valid) {
            [pairs addObject:@[ key, value ]];
        }
    }
    if (!valid) {
        *error = [NSString stringWithFormat:@"dfzf: cannot parse criteria: %@", text];
        return nil;
    }
    return pairs;
}

typedef BOOL (^DFZMatcher)(DFZWindowInfo *info, DFZState *state);

// Matches windows like dfzf-hs-msg does on the tree: con_id by equality, the
// other keys as unanchored regexes (jq's test()). Runs on the state queue.
static DFZMatcher criteriaMatcher(NSString *text, NSString **error) {
    NSArray<NSArray<NSString *> *> *pairs = parseCriteria(text, error);
    if (!pairs) {
        return nil;
    }
    NSMutableArray<DFZMatcher> *matchers = [NSMutableArray array];
    for (NSArray<NSString *> *pair in pairs) {
        NSString *key = pair[0];
        NSString *value = pair[1];
        if ([key isEqualToString:@"con_id"]) {
            [matchers addObject:^BOOL(DFZWindowInfo *info, DFZState *state) {
                return [[NSString stringWithFormat:@"%u", info.windowId] isEqualToString:value];
            }];
            continue;
        }
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:value options:0 error:NULL];
        if (!regex) {
            *error = [NSString stringWithFormat:@"dfzf: invalid regex in criteria: %@", value];
            return nil;
        }
        BOOL (^test)(NSString *) = ^BOOL(NSString *subject) {
            return [regex firstMatchInString:subject options:0 range:NSMakeRange(0, subject.length)] != nil;
        };
        if ([key isEqualToString:@"title"]) {
            [matchers addObject:^BOOL(DFZWindowInfo *info, DFZState *state) {
                return test(info.title ?: @"");
            }];
        } else if ([key isEqualToString:@"con_mark"]) {
            [matchers addObject:^BOOL(DFZWindowInfo *info, DFZState *state) {
                for (NSString *mark in [state marksOfWindow:info.windowId]) {
                    if (test(mark)) {
                        return YES;
                    }
                }
                return NO;
            }];
        } else {
            [matchers addObject:^BOOL(DFZWindowInfo *info, DFZState *state) {
                return test([state appId:info] ?: @"");
            }];
        }
    }
    return ^BOOL(DFZWindowInfo *info, DFZState *state) {
        for (DFZMatcher matcher in matchers) {
            if (!matcher(info, state)) {
                return NO;
            }
        }
        return YES;
    };
}

// Closing a popup lets its app (kitty, which also hosts dfzf-term) activate
// itself again: for this long, its windows cannot take the focus back from
// the window the popup handed it to.
static const NSTimeInterval kHandoffSeconds = 1.0;
// Opening a popup activates its app (kitty), which may first focus another of
// its windows (dfzf-term): such focus changes this close to the opening are
// not where the user came from.
static const NSTimeInterval kPopupOpeningSeconds = 1.0;
// A hotkey about to open a popup notes the focused window: the first popup
// seen within this delay adopts it as the window to go back to.
static const NSTimeInterval kPopupOriginSeconds = 5.0;

@implementation DFZController {
    id<DFZWindowSource> _source;
    DFZConfig *_config;
    DFZState *_state;
    dispatch_queue_t _stateQueue;
    // State queue only. Popup that focused another window, and that window.
    DFZWindowID _handoffPopup;
    DFZWindowID _handoffTarget;
    // Set once the popup is gone: the app to keep off the target until then.
    pid_t _handoffPid;
    NSTimeInterval _handoffUntil;
    // State queue only. When each popup was first seen.
    NSMutableDictionary<NSNumber *, NSNumber *> *_popupOpenedAt;
    // State queue only. Window focused when a popup hotkey fired, and when;
    // then the window each popup adopted from it.
    DFZWindowID _pendingOrigin;
    NSTimeInterval _pendingOriginAt;
    NSMutableDictionary<NSNumber *, NSNumber *> *_popupOrigin;
}

- (instancetype)initWithSource:(id<DFZWindowSource>)source config:(DFZConfig *)config {
    if ((self = [super init])) {
        _source = source;
        _config = config;
        _state = [DFZState new];
        _state.identityTitles = config.identityTitles;
        _stateQueue = dispatch_queue_create("dfzf.state", DISPATCH_QUEUE_SERIAL);
        _popupOpenedAt = [NSMutableDictionary dictionary];
        _popupOrigin = [NSMutableDictionary dictionary];
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
        if ([self->_config.popupTitles containsObject:info.title] && !self->_popupOpenedAt[@(info.windowId)]) {
            self->_popupOpenedAt[@(info.windowId)] = @(self->_state.clock());
            [self adoptPendingOrigin:info.windowId];
        }
    });
    BOOL place = event == DFZWindowEventCreated
        || (event == DFZWindowEventTitleChanged && [_config.popupTitles containsObject:info.title]);
    if (place && info.standard) {
        [self place:info];
    }
}

- (void)windowSourceDidRemoveWindow:(DFZWindowID)windowId {
    dispatch_async(_stateQueue, ^{
        if (windowId == self->_handoffPopup) {
            [self armHandoffFromPopup:windowId];
        } else if ([self isPopup:windowId]) {
            [self restoreFocusFromPopup:windowId];
        }
        [self->_popupOpenedAt removeObjectForKey:@(windowId)];
        [self->_popupOrigin removeObjectForKey:@(windowId)];
        [self->_state removeWindow:windowId];
    });
}

- (void)windowSourceDidFocusWindow:(DFZWindowID)windowId {
    dispatch_async(_stateQueue, ^{
        [self guardHandoffAgainst:windowId];
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
        double ratio = self->_config.popupRatio;
        NSRect centered = NSMakeRect(area.origin.x + area.size.width * (1 - ratio) / 2,
                                     area.origin.y + area.size.height * (1 - ratio) / 2,
                                     area.size.width * ratio, area.size.height * ratio);
        if ([self->_config.popupTitles containsObject:title]) {
            [self->_source setFrame:centered ofWindow:windowId];
            [self->_source focusWindow:windowId];
            [self closePopupsOlderThan:windowId];
        } else if ([self->_config.centeredTitles containsObject:title]) {
            [self->_source setFrame:centered ofWindow:windowId];
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

#pragma mark - Popup handoff (on the state queue)

- (BOOL)isPopup:(DFZWindowID)windowId {
    DFZWindowInfo *info = [_state window:windowId];
    return info && [_config.popupTitles containsObject:info.title];
}

// A popup hotkey fired: remember the window the user is on, and drop the
// previous popup's handoff so it cannot take the focus from the new one.
- (void)notePopupOrigin {
    _handoffPopup = 0;
    _handoffUntil = 0;
    DFZWindowID focused = _state.focusedId;
    _pendingOrigin = [self isPopup:focused] ? 0 : focused;
    _pendingOriginAt = _state.clock();
}

- (void)adoptPendingOrigin:(DFZWindowID)popup {
    if (_pendingOrigin && _state.clock() - _pendingOriginAt <= kPopupOriginSeconds) {
        _popupOrigin[@(popup)] = @(_pendingOrigin);
    }
    _pendingOrigin = 0;
}

- (BOOL)canRestoreTo:(DFZWindowInfo *)info popup:(DFZWindowID)popup {
    return info && info.windowId != popup && info.standard && !info.minimized
        && ![_config.popupTitles containsObject:info.title];
}

// A focus request from a popup: remember where it sent the focus, for when it closes.
- (void)noteFocusRequest:(DFZWindowID)target {
    _handoffPopup = 0;
    if ([self isPopup:target]) {
        return;
    }
    for (DFZWindowInfo *info in [_state windows]) {
        if ([_config.popupTitles containsObject:info.title] && info.windowId > _handoffPopup) {
            _handoffPopup = info.windowId;
        }
    }
    _handoffTarget = target;
}

- (void)armHandoffFromPopup:(DFZWindowID)popup {
    _handoffPopup = 0;
    DFZWindowInfo *target = [_state window:_handoffTarget];
    if (!target) {
        return;
    }
    _handoffPid = [_state window:popup].pid;
    _handoffUntil = _state.clock() + kHandoffSeconds;
    if (_state.focusedId != _handoffTarget) {
        [self refocusHandoffTarget];
    }
}

// A popup closed without focusing anything (esc): hand the focus back to the
// window used before it, unless it is already elsewhere (a clicked
// notification's app) or on a newer popup.
- (void)restoreFocusFromPopup:(DFZWindowID)popup {
    pid_t popupPid = [_state window:popup].pid;
    DFZWindowID focused = _state.focusedId;
    if (focused && focused != popup && [_state window:focused].pid != popupPid) {
        return;
    }
    NSArray<DFZWindowInfo *> *windows = [_state windows];
    for (DFZWindowInfo *info in windows) {
        if (info.windowId > popup && [_config.popupTitles containsObject:info.title]) {
            return;
        }
    }
    DFZWindowInfo *origin = [_state window:_popupOrigin[@(popup)].unsignedIntValue];
    DFZWindowID previous = [self canRestoreTo:origin popup:popup] ? origin.windowId : 0;
    long long previousRecency = 0;
    NSNumber *openedAt = _popupOpenedAt[@(popup)];
    long long openingMs = openedAt ? (long long)floor((openedAt.doubleValue - kPopupOpeningSeconds) * 1000) : LLONG_MAX;
    for (DFZWindowInfo *info in previous ? @[] : windows) {
        if (![self canRestoreTo:info popup:popup]) {
            continue;
        }
        long long recency = [_state recencyOfWindow:info.windowId];
        if (info.pid == popupPid && recency >= openingMs) {
            continue;
        }
        if (recency > previousRecency) {
            previous = info.windowId;
            previousRecency = recency;
        }
    }
    if (!previous) {
        return;
    }
    _handoffTarget = previous;
    [self armHandoffFromPopup:popup];
}

- (void)guardHandoffAgainst:(DFZWindowID)windowId {
    if (!_handoffUntil || windowId == _handoffTarget || [self isPopup:windowId]) {
        return;
    }
    if (_state.clock() > _handoffUntil) {
        _handoffUntil = 0;
        return;
    }
    if ([_state window:windowId].pid == _handoffPid) {
        [self refocusHandoffTarget];
    }
}

- (void)refocusHandoffTarget {
    DFZWindowID target = _handoffTarget;
    dispatch_queue_t queue = [_source queueForWindow:target];
    if (queue) {
        dispatch_async(queue, ^{
            [self->_source focusWindow:target];
        });
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
        return [self focus:windowId deadline:deadline error:error] ? @"" : nil;
    }
    if ([op isEqualToString:@"focusToggle"]) {
        return [self focusToggle:req deadline:deadline error:error];
    }
    if ([op isEqualToString:@"popupOrigin"]) {
        dispatch_sync(_stateQueue, ^{
            [self notePopupOrigin];
        });
        return @"";
    }
    if ([op isEqualToString:@"hideApp"]) {
        double pid = 0;
        if (!numberFrom(req[@"pid"], &pid) || pid <= 0) {
            *error = @"";
            return nil;
        }
        [_source hideApplication:(pid_t)pid];
        return @"";
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

// Unminimizes the window first: `scratchpad show` and `focus` alike bring it back.
- (BOOL)focus:(DFZWindowID)windowId deadline:(dispatch_time_t)deadline error:(NSString **)error {
    __block BOOL minimized = NO;
    [self withState:^(DFZState *state) {
        minimized = [state window:windowId].minimized;
        [self noteFocusRequest:windowId];
    }];
    return [self onWindow:windowId deadline:deadline error:error run:^{
        if (minimized) {
            [self->_source setWindow:windowId minimized:NO];
        }
        [self->_source focusWindow:windowId];
    }];
}

// dfzf-focus-toggle in a single request, with the same decisions as the script:
// jump to the target remembering the window we came from (mark
// _dfzf-origin-<key>), jump back to it when already on the target, or reply
// "missing" so the caller creates the target. Decisions and marks happen in
// one state block: no probe marks and no round trip per step.
- (NSString *)focusToggle:(NSDictionary *)req deadline:(dispatch_time_t)deadline error:(NSString **)error {
    NSString *key = stringFrom(req[@"key"]);
    NSString *criteria = stringFrom(req[@"criteria"]);
    if (!key.length || !criteria) {
        *error = @"";
        return nil;
    }
    DFZMatcher matches = criteriaMatcher(criteria, error);
    if (!matches) {
        return nil;
    }
    BOOL fallback = [req[@"fallback"] isKindOfClass:[NSNumber class]] && [req[@"fallback"] boolValue];
    NSString *originMark = [@"_dfzf-origin-" stringByAppendingString:key];
    __block DFZWindowID focusTarget = 0;
    __block BOOL missing = NO;
    [self withState:^(DFZState *state) {
        NSArray<DFZWindowInfo *> *windows = [state treeWindows];
        DFZWindowID current = 0;
        BOOL onTarget = NO;
        NSMutableSet<NSNumber *> *targets = [NSMutableSet set];
        for (DFZWindowInfo *info in windows) {
            BOOL focused = info.windowId == state.focusedId;
            if (focused) {
                current = info.windowId;
            }
            if (matches(info, state)) {
                [targets addObject:@(info.windowId)];
                onTarget = onTarget || focused;
                // sway applies `focus` to each match in turn: the last one wins.
                focusTarget = info.windowId;
            }
        }
        if (!onTarget) {
            missing = targets.count == 0;
            // The fallback creates the target: the current window is the
            // origin to come back to. Marks are unique, so marking it moves
            // the mark off the previous origin.
            if (current && (!missing || fallback)) {
                [state setMark:originMark onWindow:current add:YES];
            } else {
                [state unmark:originMark windows:nil];
            }
            return;
        }
        // Already on the target: back to the origin if it is still around, else
        // to the most recent visible window that is not a target (an origin lost,
        // or left on the target itself, must not turn the toggle into a no-op).
        DFZWindowID back = 0;
        long long backRecency = -1;
        for (DFZWindowInfo *info in windows) {
            // A hidden switcher is no window to go back to.
            if (info.minimized || info.windowId == current || [targets containsObject:@(info.windowId)]
                || [self->_config.centeredTitles containsObject:info.title]) {
                continue;
            }
            if ([[state marksOfWindow:info.windowId] containsObject:originMark]) {
                back = info.windowId;
                break;
            }
            long long recency = [state recencyOfWindow:info.windowId];
            if (recency >= backRecency) {
                back = info.windowId;
                backRecency = recency;
            }
        }
        [state unmark:originMark windows:nil];
        focusTarget = back;
    }];
    if (missing) {
        return @"missing";
    }
    if (!focusTarget) {
        return @"";
    }
    return [self focus:focusTarget deadline:deadline error:error] ? @"" : nil;
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
