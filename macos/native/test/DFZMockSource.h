#import "DFZWindowSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface DFZMockWindow : NSObject
@property (nonatomic, strong) DFZWindowInfo *info;
@property (nonatomic) NSRect frame;
@property (nonatomic) NSInteger setFrameCount;
@end

// In-memory window source: same queue discipline as DFZAXSource (one serial
// queue per pid, events posted from it), with optional per-app slowness.
@interface DFZMockSource : NSObject <DFZWindowSource>
@property (nonatomic, copy) NSArray<NSNumber *> *frontToBack;
@property (atomic) DFZWindowID focusedId;
- (void)addWindow:(DFZWindowID)windowId title:(NSString *)title app:(NSString *)app pid:(pid_t)pid;
- (void)addWindow:(DFZWindowInfo *)info event:(DFZWindowEvent)event;
- (void)emitFocus:(DFZWindowID)windowId;
- (void)emitTitleChange:(DFZWindowID)windowId;
// Every action on this app sleeps first, like an app stuck in its main thread.
- (void)setDelay:(NSTimeInterval)delay forPid:(pid_t)pid;
- (nullable DFZMockWindow *)window:(DFZWindowID)windowId;
// Waits until every app queue has drained.
- (void)flush;
@end

DFZWindowInfo *DFZMakeWindow(DFZWindowID windowId, NSString *title, NSString *app, pid_t pid, BOOL standard);

NS_ASSUME_NONNULL_END
