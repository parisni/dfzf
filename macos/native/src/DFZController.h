#import "DFZState.h"

NS_ASSUME_NONNULL_BEGIN

@interface DFZConfig : NSObject
@property (nonatomic, copy) NSSet<NSString *> *identityTitles;
@property (nonatomic, copy) NSSet<NSString *> *popupTitles;
@property (nonatomic, copy) NSSet<NSString *> *floatingTitles;
@property (nonatomic) double popupRatio;
@property (nonatomic) BOOL maximize;
// Upper bound on a request waiting for an unresponsive app.
@property (nonatomic) NSTimeInterval actionTimeout;
@end

// Serves the dfzf JSON requests (same ops and errors as the Lua spoon) from any
// thread: reads only touch the state queue, actions go through the app queues.
@interface DFZController : NSObject <DFZWindowSourceDelegate>
- (instancetype)initWithSource:(id<DFZWindowSource>)source config:(DFZConfig *)config;
- (BOOL)start:(NSString *_Nullable *_Nullable)error;
- (void)stop;
// Blocking: never call it from the state queue or an app queue.
- (NSString *)handleRequest:(NSData *)request ok:(BOOL *)ok;
// Runs the block on the state queue and waits for it.
- (void)withState:(void (^)(DFZState *state))block;
@end

NS_ASSUME_NONNULL_END
