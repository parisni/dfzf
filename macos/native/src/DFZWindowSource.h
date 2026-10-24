#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef uint32_t DFZWindowID;

// Snapshot of one window as reported by a source; never mutated once handed over.
@interface DFZWindowInfo : NSObject
@property (nonatomic) DFZWindowID windowId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *appName;
@property (nonatomic) pid_t pid;
@property (nonatomic) BOOL minimized;
@property (nonatomic) BOOL standard;
@end

// Frames use the top-left origin of the primary screen, like hs.window/hs.screen.
@interface DFZScreenInfo : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic) NSRect frame;
@property (nonatomic) NSRect fullFrame;
@end

typedef NS_ENUM(NSInteger, DFZWindowEvent) {
    DFZWindowEventScanned,
    DFZWindowEventCreated,
    DFZWindowEventTitleChanged,
    DFZWindowEventChanged,
};

// Called from the source's own queues, never from the main thread.
@protocol DFZWindowSourceDelegate <NSObject>
- (void)windowSourceDidUpdateWindow:(DFZWindowInfo *)info event:(DFZWindowEvent)event;
- (void)windowSourceDidRemoveWindow:(DFZWindowID)windowId;
- (void)windowSourceDidFocusWindow:(DFZWindowID)windowId;
- (void)windowSourceDidFinishInitialScan:(NSArray<NSNumber *> *)frontToBack;
@end

@protocol DFZWindowSource <NSObject>
- (BOOL)startWithDelegate:(id<DFZWindowSourceDelegate>)delegate error:(NSString *_Nullable *_Nullable)error;
- (void)stop;
// Serial queue of the app owning the window, nil for an unknown window. The
// window actions below may block on that app: only call them on this queue.
- (nullable dispatch_queue_t)queueForWindow:(DFZWindowID)windowId;
- (void)focusWindow:(DFZWindowID)windowId;
- (void)closeWindow:(DFZWindowID)windowId;
- (void)setWindow:(DFZWindowID)windowId minimized:(BOOL)minimized;
- (BOOL)getFrame:(NSRect *)frame ofWindow:(DFZWindowID)windowId;
- (void)setFrame:(NSRect)frame ofWindow:(DFZWindowID)windowId;
// Hides the application, as Cmd-H does; any thread.
- (void)hideApplication:(pid_t)pid;
// Thread-safe; the primary screen comes first.
- (NSArray<DFZScreenInfo *> *)screens;
@end

NS_ASSUME_NONNULL_END
