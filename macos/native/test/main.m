// Native core of hs._dfzf against DFZMockSource, through the real socket
// server. Mirrors tests/macos/test_spoon.lua. Usage: dfzf-test <tree.json fixture>
#import "DFZController.h"
#import "DFZMockSource.h"
#import "DFZServer.h"

#include <signal.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

static NSTimeInterval gClock = 1000.0;
static int gFailures = 0;

static void check(NSString *name, BOOL condition) {
    printf("%s %s\n", condition ? "ok  " : "FAIL", name.UTF8String);
    if (!condition) {
        gFailures++;
    }
}

static NSString *sendRequest(NSString *path, NSString *json, BOOL *ok) {
    *ok = NO;
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un address;
    memset(&address, 0, sizeof(address));
    address.sun_family = AF_UNIX;
    strncpy(address.sun_path, path.fileSystemRepresentation, sizeof(address.sun_path) - 1);
    if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0) {
        close(fd);
        return @"<connect failed>";
    }
    NSData *line = [[json stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    if (write(fd, line.bytes, line.length) != (ssize_t)line.length) {
        close(fd);
        return @"<write failed>";
    }
    NSMutableData *reply = [NSMutableData data];
    char buffer[4096];
    ssize_t count;
    while ((count = read(fd, buffer, sizeof(buffer))) > 0) {
        [reply appendBytes:buffer length:(size_t)count];
    }
    close(fd);
    NSString *text = [[NSString alloc] initWithData:reply encoding:NSUTF8StringEncoding] ?: @"";
    NSRange newline = [text rangeOfString:@"\n"];
    if (newline.location == NSNotFound) {
        return @"<no reply>";
    }
    *ok = [[text substringToIndex:newline.location] isEqualToString:@"ok"];
    return [text substringFromIndex:newline.location + 1];
}

static id parse(NSString *json) {
    return [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
}

static void collectCons(id node, NSMutableArray *cons) {
    if (![node isKindOfClass:[NSDictionary class]]) {
        return;
    }
    if ([node[@"type"] isEqual:@"con"]) {
        [cons addObject:node];
    }
    for (id child in node[@"nodes"]) {
        collectCons(child, cons);
    }
}

// hs.json encodes empty Lua tables as objects: the fixture keeps that quirk,
// the native tree does not (dfzf-hs-msg normalizes the same way).
static id normalize(id value) {
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *items = [NSMutableArray array];
        for (id item in value) {
            [items addObject:normalize(item)];
        }
        return items;
    }
    if (![value isKindOfClass:[NSDictionary class]]) {
        return value;
    }
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [value enumerateKeysAndObjectsUsingBlock:^(id key, id item, BOOL *stop) {
        (void)stop;
        BOOL list = [@[ @"marks", @"nodes", @"floating_nodes" ] containsObject:key];
        result[key] = (list && [item isKindOfClass:[NSDictionary class]] && [item count] == 0) ? @[] : normalize(item);
    }];
    return result;
}

@interface DFZHarness : NSObject
@property (nonatomic, strong) DFZMockSource *mock;
@property (nonatomic, strong) DFZController *controller;
@property (nonatomic, strong) DFZServer *server;
@property (nonatomic, copy) NSString *path;
@end

@implementation DFZHarness

- (instancetype)initWithPath:(NSString *)path {
    if ((self = [super init])) {
        _path = path;
        _mock = [DFZMockSource new];
        DFZConfig *config = [DFZConfig new];
        config.identityTitles =
            [NSSet setWithArray:@[ @"dfzf-popup", @"dfzf-term", @"dfzf-hidden", @"dfzf-git", @"dfzf-scratchpad" ]];
        config.popupTitles = [NSSet setWithObject:@"dfzf-popup"];
        config.floatingTitles = [NSSet setWithArray:@[ @"dfzf-git", @"dfzf-scratchpad" ]];
        _controller = [[DFZController alloc] initWithSource:_mock config:config];
        [_controller withState:^(DFZState *state) {
            state.clock = ^NSTimeInterval {
                return gClock;
            };
        }];
        DFZController *controller = _controller;
        _server = [[DFZServer alloc] initWithPath:path
                                          handler:^NSString *(NSData *request, BOOL *ok) {
                                              return [controller handleRequest:request ok:ok];
                                          }];
    }
    return self;
}

- (BOOL)start {
    NSString *error = nil;
    BOOL started = [_controller start:&error] && [_server start:&error];
    if (!started) {
        printf("FAIL start: %s\n", error.UTF8String);
        gFailures++;
    }
    [self settle];
    return started;
}

- (void)stop {
    [_server stop];
    [_controller stop];
}

// Source events hop app queue -> state queue, placement hops back: drain both twice.
- (void)settle {
    for (int round = 0; round < 2; round++) {
        [_mock flush];
        [_controller withState:^(DFZState *state) {
            (void)state;
        }];
    }
}

- (NSString *)request:(NSString *)json ok:(BOOL *)ok {
    NSString *reply = sendRequest(_path, json, ok);
    [self settle];
    return reply;
}

- (NSString *)request:(NSString *)json {
    BOOL ok = NO;
    return [self request:json ok:&ok];
}

- (NSString *)marks:(DFZWindowID)windowId {
    __block NSString *marks;
    [_controller withState:^(DFZState *state) {
        marks = [[state marksOfWindow:windowId] componentsJoinedByString:@","];
    }];
    return marks;
}

- (id)tree {
    return parse([self request:@"{\"op\":\"tree\"}"]);
}

@end

static void testSpoonParity(NSString *directory) {
    NSString *path = [directory stringByAppendingPathComponent:@"state/dfzf/hs.sock"];
    DFZHarness *h = [[DFZHarness alloc] initWithPath:path];
    [h.mock addWindow:1 title:@"Inbox - mail.google.com" app:@"Firefox" pid:4242];
    [h.mock addWindow:2 title:@"hx main.go" app:@"kitty" pid:4242];
    [h.mock addWindow:DFZMakeWindow(3, @"Sheet", @"Firefox", 4242, NO) event:DFZWindowEventScanned];
    h.mock.frontToBack = @[ @2, @1 ];
    [h start];

    struct stat info;
    check(@"socket is private (0600)", stat(path.fileSystemRepresentation, &info) == 0 && (info.st_mode & 0777) == 0600);
    check(@"socket directory is private (0700)",
          stat(path.stringByDeletingLastPathComponent.fileSystemRepresentation, &info) == 0
              && (info.st_mode & 0777) == 0700);

    check(@"seed: front window most recent",
          [[h marks:2] isEqualToString:@"_dfzf-sort-999999"] && [[h marks:1] isEqualToString:@"_dfzf-sort-999998"]);

    gClock = 2000.0;
    [h.mock emitFocus:1];
    [h settle];
    check(@"focus event refreshes recency", [[h marks:1] isEqualToString:@"_dfzf-sort-2000000"]);

    [h request:@"{\"op\":\"markToggle\",\"id\":1,\"prefix\":\"_dfzf-red\",\"appendTs\":true}"];
    check(@"markToggle adds timestamped mark",
          [[h marks:1] rangeOfString:@"^_dfzf-sort-2000000,_dfzf-red-[0-9]+$" options:NSRegularExpressionSearch]
                  .location
              != NSNotFound);
    [h request:@"{\"op\":\"markToggle\",\"id\":1,\"prefix\":\"_dfzf-red\",\"appendTs\":true}"];
    check(@"markToggle removes it", [[h marks:1] isEqualToString:@"_dfzf-sort-2000000"]);

    [h request:@"{\"op\":\"markToggle\",\"id\":2,\"prefix\":\"_dfzf-preview\",\"appendTs\":false}"];
    gClock = 3000.0;
    [h.mock emitFocus:2];
    [h settle];
    check(@"preview mark freezes recency", [[h marks:2] isEqualToString:@"_dfzf-sort-999999,_dfzf-preview"]);
    [h request:@"{\"op\":\"markToggle\",\"id\":2,\"prefix\":\"_dfzf-preview\",\"appendTs\":false}"];
    [h.mock emitFocus:2];
    [h settle];
    check(@"grace period after preview clear", [[h marks:2] isEqualToString:@"_dfzf-sort-999999"]);
    gClock = 3001.0;
    [h.mock emitFocus:2];
    [h settle];
    check(@"recency resumes after grace", [[h marks:2] isEqualToString:@"_dfzf-sort-3001000"]);

    [h request:@"{\"op\":\"mark\",\"id\":1,\"mark\":\"_dfzf-origin-term\",\"add\":true}"];
    [h request:@"{\"op\":\"mark\",\"id\":2,\"mark\":\"_dfzf-origin-term\",\"add\":true}"];
    check(@"mark is unique (moved)",
          ![[h marks:1] containsString:@"origin"] && [[h marks:2] containsString:@"origin"]);
    [h request:@"{\"op\":\"unmark\",\"mark\":\"_dfzf-origin-term\",\"ids\":[2]}"];
    check(@"unmark by ids", ![[h marks:2] containsString:@"origin"]);
    [h request:@"{\"op\":\"mark\",\"id\":1,\"mark\":\"_x\",\"add\":false}"];
    check(@"mark without add replaces", [[h marks:1] isEqualToString:@"_x"]);
    [h request:@"{\"op\":\"unmark\",\"mark\":\"\"}"];
    check(@"bare unmark clears all", [[h marks:1] isEqualToString:@""] && [[h marks:2] isEqualToString:@""]);

    __block BOOL urgent = NO;
    [h request:@"{\"op\":\"urgent\",\"ids\":[1],\"mode\":\"toggle\"}"];
    [h.controller withState:^(DFZState *state) {
        urgent = [state isUrgent:1];
    }];
    check(@"urgent toggle", urgent);
    [h request:@"{\"op\":\"urgent\",\"ids\":[1],\"mode\":\"disable\"}"];
    [h.controller withState:^(DFZState *state) {
        urgent = [state isUrgent:1];
    }];
    check(@"urgent disable", !urgent);

    [h request:@"{\"op\":\"focus\",\"id\":2}"];
    check(@"focus handler", h.mock.focusedId == 2);

    NSMutableArray *cons = [NSMutableArray array];
    collectCons([h tree], cons);
    NSMutableArray *summary = [NSMutableArray array];
    for (NSDictionary *con in cons) {
        [summary addObject:@[ con[@"id"], con[@"app_id"], con[@"focused"], con[@"pid"] ]];
    }
    check(@"tree lists standard windows only",
          [summary isEqual:@[ @[ @1, @"firefox", @NO, @4242 ], @[ @2, @"kitty", @YES, @4242 ] ]]);

    [h request:@"{\"op\":\"hide\",\"ids\":[1]}"];
    NSMutableArray *workspaces = [NSMutableArray array];
    for (NSDictionary *workspace in [h tree][@"nodes"]) {
        [workspaces addObject:@[ workspace[@"name"], [workspace[@"nodes"] valueForKey:@"id"] ]];
    }
    check(@"hidden window moves to the scratchpad workspace",
          [workspaces isEqual:@[ @[ @"1", @[ @2 ] ], @[ @"__i3_scratch", @[ @1 ] ] ]]);
    [h request:@"{\"op\":\"show\",\"id\":1}"];
    check(@"show unminimizes and focuses", ![h.mock window:1].info.minimized && h.mock.focusedId == 1);

    [h request:@"{\"op\":\"resize\",\"id\":1,\"w\":900,\"h\":720}"];
    [h request:@"{\"op\":\"move\",\"id\":1,\"x\":50,\"y\":40}"];
    check(@"resize then move relative to the screen origin",
          NSEqualRects([h.mock window:1].frame, NSMakeRect(50, 65, 900, 720)));
    NSArray *outputs = parse([h request:@"{\"op\":\"outputs\"}"]);
    check(@"outputs report the screen frame", [outputs.firstObject[@"rect"][@"width"] isEqual:@1000]);

    [h.mock addWindow:DFZMakeWindow(4, @"dfzf-popup", @"kitty", 4242, YES) event:DFZWindowEventCreated];
    [h settle];
    NSRect popup = [h.mock window:4].frame;
    check(@"popup centered at 65%", popup.size.width == 650 && popup.origin.x == 175 && h.mock.focusedId == 4);
    [h.mock addWindow:DFZMakeWindow(7, @"dfzf-popup", @"kitty", 4242, YES) event:DFZWindowEventCreated];
    [h settle];
    [h settle];
    check(@"new popup closes the older one",
          [h.mock window:4] == nil && [h.mock window:7] != nil && h.mock.focusedId == 7);
    [h.mock addWindow:DFZMakeWindow(10, @"dfzf-popup", @"kitty", 4242, YES) event:DFZWindowEventCreated];
    [h settle];
    [h settle];
    [h.mock addWindow:DFZMakeWindow(8, @"dfzf-popup", @"kitty", 4242, YES) event:DFZWindowEventCreated];
    [h settle];
    [h settle];
    check(@"late event on an older popup keeps the newer one", [h.mock window:10] != nil && [h.mock window:7] == nil);
    [h.mock addWindow:DFZMakeWindow(9, @"hx notes.md", @"kitty", 4242, YES) event:DFZWindowEventCreated];
    [h settle];
    [h settle];
    check(@"regular window never closes popups", [h.mock window:10] != nil);
    [h.mock addWindow:DFZMakeWindow(5, @"dfzf-term", @"kitty", 4242, YES) event:DFZWindowEventCreated];
    [h settle];
    check(@"regular window maximized", NSEqualRects([h.mock window:5].frame, NSMakeRect(0, 25, 1000, 800)));
    [h.mock addWindow:DFZMakeWindow(6, @"dfzf-git", @"kitty", 4242, YES) event:DFZWindowEventCreated];
    [h settle];
    check(@"floating title left unmaximized", [h.mock window:6].setFrameCount == 0);
    [h.mock emitTitleChange:2];
    [h settle];
    check(@"title change ignored for regular window", [h.mock window:2].setFrameCount == 0);

    BOOL ok = NO;
    [h request:@"{\"op\":\"close\",\"ids\":[5,42]}" ok:&ok];
    check(@"close existing, ignore unknown", ok && [h.mock window:5] == nil);
    [h tree];
    __block BOOL pruned = NO;
    [h.controller withState:^(DFZState *state) {
        pruned = ![state hasEntry:5];
    }];
    check(@"state of closed window pruned", pruned);

    NSString *reply = [h request:@"{\"op\":\"nope\"}" ok:&ok];
    check(@"unknown op errors", !ok && [reply isEqualToString:@"dfzf: unknown request {\"op\":\"nope\"}"]);
    reply = [h request:@"{\"op\":\"focus\",\"id\":42}" ok:&ok];
    check(@"focus on unknown id errors", !ok && [reply isEqualToString:@"dfzf: no window with id 42"]);
    reply = [h request:@"{\"op\":\"hide\",\"ids\":[42]}" ok:&ok];
    check(@"hide on unknown id errors", !ok && [reply isEqualToString:@"dfzf: no window with id 42"]);
    reply = [h request:@"{\"op\":\"hide\"}" ok:&ok];
    check(@"malformed request errors", !ok && [reply isEqualToString:@"dfzf: invalid request {\"op\":\"hide\"}"]);
    reply = [h request:@"not json" ok:&ok];
    check(@"non-JSON request errors", !ok && [reply isEqualToString:@"dfzf: unknown request not json"]);

    // Each client must get the reply to its own request, not a neighbour's.
    static int mixedUp = 0;
    dispatch_apply(32, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t index) {
        BOOL tree = index % 2 == 0;
        BOOL replyOk = NO;
        NSString *payload = sendRequest(path, tree ? @"{\"op\":\"tree\"}" : @"{\"op\":\"outputs\"}", &replyOk);
        BOOL matches = replyOk && [payload hasPrefix:tree ? @"{" : @"["];
        if (!matches) {
            __atomic_fetch_add(&mixedUp, 1, __ATOMIC_SEQ_CST);
        }
    });
    check(@"concurrent clients each get their own reply", mixedUp == 0);

    [h stop];
    check(@"stop removes the socket", access(path.fileSystemRepresentation, F_OK) != 0);
}

static void testTreeFixture(NSString *directory, NSString *fixture) {
    DFZHarness *h = [[DFZHarness alloc] initWithPath:[directory stringByAppendingPathComponent:@"fixture.sock"]];
    [h.mock addWindow:11 title:@"Inbox - mail.google.com" app:@"Firefox" pid:400];
    [h.mock addWindow:22 title:@"hx main.go" app:@"kitty" pid:500];
    [h.mock addWindow:33 title:@"dfzf-popup" app:@"kitty" pid:500];
    // The fixture pairs this title with app_id "dfzf-term": an app of that name gives it.
    [h.mock addWindow:44 title:@"dfzf-term \"q\"" app:@"dfzf-term" pid:500];
    [h start];
    [h.mock emitFocus:33];
    [h settle];
    [h.controller withState:^(DFZState *state) {
        [state touch:11 timestampMs:200];
        [state setMark:@"_dfzf-red-1" onWindow:11 add:YES];
        [state touch:33 timestampMs:300];
        [state touch:44 timestampMs:100];
        [state setMark:@"_dfzf-origin-term" onWindow:44 add:YES];
        [state setUrgent:@"enable" windows:@[ @44 ]];
    }];
    id expected = normalize(parse([NSString stringWithContentsOfFile:fixture encoding:NSUTF8StringEncoding error:NULL]));
    id actual = [h tree];
    check(@"tree matches tests/macos/fixtures/tree.json", expected != nil && [actual isEqual:expected]);
    if (![actual isEqual:expected]) {
        printf("  actual: %s\n", [h request:@"{\"op\":\"tree\"}"].UTF8String);
    }
    [h stop];
}

// Closing the popup reactivates kitty, which focuses its other window back.
static void stealFocus(DFZHarness *h, DFZWindowID windowId) {
    h.mock.focusedId = windowId;
    [h.mock emitFocus:windowId];
    [h settle];
    [h settle];
}

static void testPopupHandoff(NSString *directory) {
    DFZHarness *h = [[DFZHarness alloc] initWithPath:[directory stringByAppendingPathComponent:@"handoff.sock"]];
    [h.mock addWindow:20 title:@"New Tab" app:@"Firefox" pid:900];
    [h.mock addWindow:21 title:@"dfzf-term" app:@"kitty" pid:901];
    [h.mock addWindow:22 title:@"dfzf-popup" app:@"kitty" pid:901];
    [h start];
    gClock = 5000.0;

    [h request:@"{\"op\":\"focus\",\"id\":20}"];
    [h.mock closeWindow:22];
    [h settle];
    stealFocus(h, 21);
    check(@"handoff: closed popup's app cannot steal the focus back", h.mock.focusedId == 20);

    [h.mock addWindow:23 title:@"dfzf-popup" app:@"kitty" pid:901];
    [h settle];
    gClock = 5100.0;
    [h request:@"{\"op\":\"focus\",\"id\":20}"];
    stealFocus(h, 21);
    [h.mock closeWindow:23];
    [h settle];
    [h settle];
    check(@"handoff: steal before the popup is gone is undone too", h.mock.focusedId == 20);

    gClock = 5110.0;
    stealFocus(h, 21);
    check(@"handoff: expires after the grace period", h.mock.focusedId == 21);

    [h.mock addWindow:24 title:@"dfzf-popup" app:@"kitty" pid:901];
    [h settle];
    h.mock.focusedId = 24;
    [h.mock closeWindow:24];
    [h settle];
    stealFocus(h, 21);
    check(@"handoff: popup that focused nothing forces nothing", h.mock.focusedId == 21);

    [h.mock addWindow:25 title:@"dfzf-popup" app:@"kitty" pid:901];
    [h settle];
    [h request:@"{\"op\":\"focus\",\"id\":20}"];
    [h request:@"{\"op\":\"focus\",\"id\":25}"];
    [h.mock closeWindow:25];
    [h settle];
    stealFocus(h, 21);
    check(@"handoff: preview that refocused the popup forces nothing", h.mock.focusedId == 21);
    [h stop];
}

static void testHungApp(NSString *directory) {
    DFZHarness *h = [[DFZHarness alloc] initWithPath:[directory stringByAppendingPathComponent:@"hung.sock"]];
    [h.mock addWindow:7 title:@"spinning" app:@"Slow" pid:700];
    [h.mock addWindow:8 title:@"fine" app:@"Fast" pid:800];
    [h start];
    [h.mock setDelay:3.0 forPid:700];

    __block BOOL slowOk = YES;
    __block NSString *slowReply = nil;
    __block NSTimeInterval slowSeconds = 0;
    dispatch_semaphore_t slowDone = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDate *start = [NSDate date];
        BOOL ok = YES;
        slowReply = sendRequest(h.path, @"{\"op\":\"focus\",\"id\":7}", &ok);
        slowOk = ok;
        slowSeconds = -start.timeIntervalSinceNow;
        dispatch_semaphore_signal(slowDone);
    });
    [NSThread sleepForTimeInterval:0.2];

    BOOL ok = NO;
    NSDate *start = [NSDate date];
    NSString *tree = sendRequest(h.path, @"{\"op\":\"tree\"}", &ok);
    check(@"hung app does not block tree", ok && [tree hasPrefix:@"{"] && -start.timeIntervalSinceNow < 0.5);
    start = [NSDate date];
    sendRequest(h.path, @"{\"op\":\"focus\",\"id\":8}", &ok);
    check(@"hung app does not block actions on other apps", ok && -start.timeIntervalSinceNow < 0.5);

    dispatch_semaphore_wait(slowDone, DISPATCH_TIME_FOREVER);
    check(@"action on hung app fails after ~2s",
          !slowOk && [slowReply isEqualToString:@"dfzf: window 7 did not respond within 2s"] && slowSeconds > 1.8
              && slowSeconds < 2.8);
    [h stop];
}

static NSString *toggleRequest(NSString *key, NSString *criteria, BOOL fallback) {
    NSDictionary *request = @{ @"op" : @"focusToggle", @"key" : key, @"criteria" : criteria, @"fallback" : @(fallback) };
    NSData *data = [NSJSONSerialization dataWithJSONObject:request options:0 error:NULL];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

// Mirrors tests/macos/test_focus_toggle.sh, decided in one request.
static void testFocusToggle(NSString *directory) {
    DFZHarness *h = [[DFZHarness alloc] initWithPath:[directory stringByAppendingPathComponent:@"toggle.sock"]];
    [h.mock addWindow:1 title:@"Inbox - mail.google.com" app:@"Firefox" pid:300];
    [h.mock addWindow:2 title:@"hx main.go" app:@"kitty" pid:301];
    [h.mock addWindow:3 title:@"general - Slack" app:@"Slack" pid:302];
    DFZWindowInfo *hidden = DFZMakeWindow(4, @"Huddle - Slack", @"Slack", 302, YES);
    hidden.minimized = YES;
    [h.mock addWindow:hidden event:DFZWindowEventScanned];
    [h.mock addWindow:5 title:@"say \"hi\"" app:@"Notes" pid:303];
    h.mock.frontToBack = @[ @2, @1, @3 ];
    [h start];
    NSString *slack = @"[app_id=\"^slack$\" title=\"general\"]";

    gClock = 5000.0;
    [h.mock emitFocus:2];
    [h settle];
    BOOL ok = NO;
    NSString *reply = [h request:toggleRequest(@"slack", slack, NO) ok:&ok];
    check(@"toggle: jumps to the target", ok && [reply isEqualToString:@""] && h.mock.focusedId == 3);
    check(@"toggle: remembers the origin", [[h marks:2] containsString:@"_dfzf-origin-slack"]);

    reply = [h request:toggleRequest(@"slack", slack, NO) ok:&ok];
    check(@"toggle: on target, back to the origin", ok && h.mock.focusedId == 2);
    check(@"toggle: origin mark cleared", ![[h marks:2] containsString:@"origin"]);

    gClock = 6000.0;
    [h.mock emitFocus:1];
    [h settle];
    [h request:@"{\"op\":\"focus\",\"id\":3}"];
    [h request:toggleRequest(@"slack", slack, NO) ok:&ok];
    check(@"toggle: no origin, most recent other window", ok && h.mock.focusedId == 1);

    [h request:toggleRequest(@"huddle", @"[title=\"^Huddle\"]", NO) ok:&ok];
    check(@"toggle: minimized target is unminimized", ok && h.mock.focusedId == 4 && ![h.mock window:4].info.minimized);
    check(@"toggle: origin marked before jumping", [[h marks:1] containsString:@"_dfzf-origin-huddle"]);

    [h request:@"{\"op\":\"focus\",\"id\":2}"];
    reply = [h request:toggleRequest(@"absent", @"[app_id=\"^absent$\"]", YES) ok:&ok];
    check(@"toggle: missing target replies missing", ok && [reply isEqualToString:@"missing"] && h.mock.focusedId == 2);
    check(@"toggle: missing target with fallback marks the origin", [[h marks:2] containsString:@"_dfzf-origin-absent"]);
    reply = [h request:toggleRequest(@"absent", @"[app_id=\"^absent$\"]", NO) ok:&ok];
    check(@"toggle: missing target without fallback clears the origin",
          ok && [reply isEqualToString:@"missing"] && ![[h marks:2] containsString:@"origin"]);

    [h request:toggleRequest(@"mail", @"[app_id=firefox title=\"mail\\.google\\.com\"]", NO) ok:&ok];
    check(@"toggle: bareword and regex escapes", ok && h.mock.focusedId == 1);
    [h request:toggleRequest(@"quote", @"[title=\"say \\\"hi\\\"\"]", NO) ok:&ok];
    check(@"toggle: escaped quote is unescaped", ok && h.mock.focusedId == 5);

    reply = [h request:toggleRequest(@"x", @"[workspace=\"1\"]", NO) ok:&ok];
    check(@"toggle: unsupported criteria key errors",
          !ok && [reply isEqualToString:@"dfzf: unsupported on macOS: criteria key 'workspace'"]);
    reply = [h request:toggleRequest(@"x", @"[app_id=\"slack]", NO) ok:&ok];
    check(@"toggle: unterminated criteria errors", !ok && [reply hasPrefix:@"dfzf: cannot parse criteria"]);
    reply = [h request:@"{\"op\":\"focusToggle\",\"criteria\":\"[]\"}" ok:&ok];
    check(@"toggle: missing key is invalid", !ok && [reply hasPrefix:@"dfzf: invalid request"]);
    [h stop];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: %s <tree.json fixture>\n", argv[0]);
            return 2;
        }
        signal(SIGPIPE, SIG_IGN);
        // Short base path: sun_path only holds about a hundred bytes.
        char base[] = "/tmp/dfzf-test.XXXXXX";
        NSString *directory = @(mkdtemp(base));
        testSpoonParity(directory);
        testTreeFixture(directory, @(argv[1]));
        testPopupHandoff(directory);
        testHungApp(directory);
        testFocusToggle(directory);
        [[NSFileManager defaultManager] removeItemAtPath:directory error:NULL];
    }
    return gFailures == 0 ? 0 : 1;
}
