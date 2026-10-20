#import "DFZWindowSource.h"

NS_ASSUME_NONNULL_BEGIN

// Window list, marks, recency and urgency, with the semantics of the Lua spoon.
// Not thread-safe: DFZController confines it to one serial queue.
@interface DFZState : NSObject
@property (nonatomic, copy) NSSet<NSString *> *identityTitles;
// Seconds since the epoch; replaceable by tests.
@property (nonatomic, copy) NSTimeInterval (^clock)(void);
@property (nonatomic, readonly) DFZWindowID focusedId;
// Pruning of vanished windows waits for the initial scan: until then the
// window list is incomplete and would drop the seeded recency.
@property (nonatomic) BOOL scanComplete;

- (void)upsertWindow:(DFZWindowInfo *)info;
- (void)removeWindow:(DFZWindowID)windowId;
- (nullable DFZWindowInfo *)window:(DFZWindowID)windowId;
- (void)focusWindow:(DFZWindowID)windowId;
- (void)seedRecency:(NSArray<NSNumber *> *)frontToBack;
- (void)touch:(DFZWindowID)windowId timestampMs:(long long)timestampMs;

- (void)setMark:(NSString *)mark onWindow:(DFZWindowID)windowId add:(BOOL)add;
- (void)unmark:(NSString *)mark windows:(nullable NSArray<NSNumber *> *)ids;
- (void)markToggle:(NSString *)prefix onWindow:(DFZWindowID)windowId appendTs:(BOOL)appendTs;
- (void)setUrgent:(NSString *)mode windows:(NSArray<NSNumber *> *)ids;

- (NSArray<NSString *> *)marksOfWindow:(DFZWindowID)windowId;
- (BOOL)isUrgent:(DFZWindowID)windowId;
- (BOOL)hasEntry:(DFZWindowID)windowId;
- (NSString *)treeJSON;
@end

NS_ASSUME_NONNULL_END
