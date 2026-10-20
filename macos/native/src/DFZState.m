#import "DFZState.h"

static NSString *const kPreviewMark = @"_dfzf-preview";
static NSString *const kSortPrefix = @"_dfzf-sort";
// Focus events are delivered asynchronously and can land after a preview has
// already cleared its mark: ignore them for this long after the clear.
static const NSTimeInterval kPreviewGraceSeconds = 0.5;

@interface DFZEntry : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *marks;
@property (nonatomic) BOOL urgent;
@end

@implementation DFZEntry
- (instancetype)init {
    if ((self = [super init])) {
        _marks = [NSMutableArray array];
    }
    return self;
}
@end

static id jsonBool(BOOL value) {
    return value ? @YES : @NO;
}

@implementation DFZState {
    NSMutableArray<NSNumber *> *_order;
    NSMutableDictionary<NSNumber *, DFZWindowInfo *> *_windows;
    NSMutableDictionary<NSNumber *, DFZEntry *> *_entries;
    NSMutableDictionary<NSNumber *, NSNumber *> *_previewGraceUntil;
}

- (instancetype)init {
    if ((self = [super init])) {
        _order = [NSMutableArray array];
        _windows = [NSMutableDictionary dictionary];
        _entries = [NSMutableDictionary dictionary];
        _previewGraceUntil = [NSMutableDictionary dictionary];
        _identityTitles = [NSSet set];
        _clock = ^NSTimeInterval {
            return [[NSDate date] timeIntervalSince1970];
        };
    }
    return self;
}

- (DFZEntry *)entry:(DFZWindowID)windowId {
    DFZEntry *entry = _entries[@(windowId)];
    if (!entry) {
        entry = [DFZEntry new];
        _entries[@(windowId)] = entry;
    }
    return entry;
}

- (void)upsertWindow:(DFZWindowInfo *)info {
    NSNumber *key = @(info.windowId);
    if (!_windows[key]) {
        [_order addObject:key];
    }
    _windows[key] = info;
}

- (void)removeWindow:(DFZWindowID)windowId {
    NSNumber *key = @(windowId);
    [_windows removeObjectForKey:key];
    [_order removeObject:key];
    [_entries removeObjectForKey:key];
    [_previewGraceUntil removeObjectForKey:key];
    if (_focusedId == windowId) {
        _focusedId = 0;
    }
}

- (nullable DFZWindowInfo *)window:(DFZWindowID)windowId {
    return _windows[@(windowId)];
}

- (void)focusWindow:(DFZWindowID)windowId {
    _focusedId = windowId;
    DFZEntry *entry = [self entry:windowId];
    // A preview only peeks at a window: it must not reorder the recency list.
    NSNumber *graceUntil = _previewGraceUntil[@(windowId)];
    if ([entry.marks containsObject:kPreviewMark] || (graceUntil && graceUntil.doubleValue > self.clock())) {
        return;
    }
    [self touch:windowId timestampMs:(long long)floor(self.clock() * 1000)];
}

- (void)seedRecency:(NSArray<NSNumber *> *)frontToBack {
    long long seed = (long long)floor(self.clock() * 1000);
    long long index = 1;
    for (NSNumber *windowId in frontToBack) {
        [self touch:windowId.unsignedIntValue timestampMs:seed - index];
        index++;
    }
}

static void removeMarks(DFZEntry *entry, BOOL (^predicate)(NSString *mark)) {
    NSIndexSet *matching = [entry.marks indexesOfObjectsPassingTest:^BOOL(NSString *mark, NSUInteger idx, BOOL *stop) {
        (void)idx;
        (void)stop;
        return predicate(mark);
    }];
    [entry.marks removeObjectsAtIndexes:matching];
}

- (void)touch:(DFZWindowID)windowId timestampMs:(long long)timestampMs {
    DFZEntry *entry = [self entry:windowId];
    removeMarks(entry, ^BOOL(NSString *mark) {
        return [mark hasPrefix:kSortPrefix];
    });
    [entry.marks addObject:[NSString stringWithFormat:@"%@-%lld", kSortPrefix, timestampMs]];
}

// Same semantics as sway: a mark lives on at most one window, so setting it
// moves it; without `add`, it replaces the window's marks.
- (void)setMark:(NSString *)mark onWindow:(DFZWindowID)windowId add:(BOOL)add {
    for (DFZEntry *entry in _entries.allValues) {
        removeMarks(entry, ^BOOL(NSString *other) {
            return [other isEqualToString:mark];
        });
    }
    DFZEntry *entry = [self entry:windowId];
    if (!add) {
        [entry.marks removeAllObjects];
    }
    [entry.marks addObject:mark];
}

- (void)unmark:(NSString *)mark windows:(nullable NSArray<NSNumber *> *)ids {
    [_entries enumerateKeysAndObjectsUsingBlock:^(NSNumber *windowId, DFZEntry *entry, BOOL *stop) {
        (void)stop;
        if (ids == nil || [ids containsObject:windowId]) {
            removeMarks(entry, ^BOOL(NSString *other) {
                return mark.length == 0 || [other isEqualToString:mark];
            });
        }
    }];
}

- (void)markToggle:(NSString *)prefix onWindow:(DFZWindowID)windowId appendTs:(BOOL)appendTs {
    DFZEntry *entry = [self entry:windowId];
    BOOL present = NO;
    for (NSString *mark in entry.marks) {
        if ([mark hasPrefix:prefix]) {
            present = YES;
        }
    }
    if (present) {
        removeMarks(entry, ^BOOL(NSString *mark) {
            return [mark hasPrefix:prefix];
        });
        if ([prefix isEqualToString:kPreviewMark]) {
            _previewGraceUntil[@(windowId)] = @(self.clock() + kPreviewGraceSeconds);
        }
    } else {
        // Wall-clock seconds on purpose, like os.time() in the Lua spoon.
        NSString *mark = appendTs ? [NSString stringWithFormat:@"%@-%ld", prefix, (long)time(NULL)] : prefix;
        [self setMark:mark onWindow:windowId add:YES];
    }
}

// macOS exposes no window urgency to read: urgency is a dfzf-only flag here.
- (void)setUrgent:(NSString *)mode windows:(NSArray<NSNumber *> *)ids {
    for (NSNumber *windowId in ids) {
        DFZEntry *entry = [self entry:windowId.unsignedIntValue];
        entry.urgent = [mode isEqualToString:@"toggle"] ? !entry.urgent : [mode isEqualToString:@"enable"];
    }
}

- (NSArray<NSString *> *)marksOfWindow:(DFZWindowID)windowId {
    return [_entries[@(windowId)].marks copy] ?: @[];
}

- (BOOL)isUrgent:(DFZWindowID)windowId {
    return _entries[@(windowId)].urgent;
}

- (BOOL)hasEntry:(DFZWindowID)windowId {
    return _entries[@(windowId)] != nil;
}

- (NSString *)appId:(DFZWindowInfo *)info {
    if ([self.identityTitles containsObject:info.title]) {
        return info.title;
    }
    return info.appName.lowercaseString;
}

static NSDictionary *container(NSInteger containerId, NSString *type, NSString *name, NSArray *nodes) {
    return @{
        @"id" : @(containerId),
        @"type" : type,
        @"name" : name,
        @"layout" : @"tabbed",
        @"focused" : @NO,
        @"marks" : @[],
        @"nodes" : nodes,
        @"floating_nodes" : @[],
    };
}

// Mirrors sway: visible windows live in workspace "1", minimized ones play
// the scratchpad ("__i3_scratch"), which dfzf scripts detect by name.
- (NSString *)treeJSON {
    if (self.scanComplete) {
        for (NSNumber *windowId in _entries.allKeys) {
            if (!_windows[windowId]) {
                [_entries removeObjectForKey:windowId];
            }
        }
    }
    NSMutableArray *visible = [NSMutableArray array];
    NSMutableArray *hidden = [NSMutableArray array];
    for (NSNumber *windowId in _order) {
        DFZWindowInfo *info = _windows[windowId];
        if (!info.standard) {
            continue;
        }
        DFZEntry *entry = _entries[windowId];
        [(info.minimized ? hidden : visible) addObject:@{
            @"id" : windowId,
            @"type" : @"con",
            @"name" : info.title,
            @"app_id" : [self appId:info],
            @"pid" : @(info.pid),
            @"marks" : entry ? [entry.marks copy] : @[],
            @"urgent" : jsonBool(entry.urgent),
            @"focused" : jsonBool(windowId.unsignedIntValue == self.focusedId),
            @"layout" : @"none",
            @"nodes" : @[],
            @"floating_nodes" : @[],
        }];
    }
    // Negative ids cannot collide with macOS window ids.
    NSDictionary *root = container(0, @"root", @"root", @[
        container(-1, @"workspace", @"1", visible),
        container(-2, @"workspace", @"__i3_scratch", hidden),
    ]);
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:0 error:NULL];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end
