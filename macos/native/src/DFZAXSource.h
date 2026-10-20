#import "DFZWindowSource.h"

NS_ASSUME_NONNULL_BEGIN

// Window source backed by the macOS Accessibility API. Each app gets its own
// serial queue so that one hung app only ever blocks requests aimed at it.
@interface DFZAXSource : NSObject <DFZWindowSource>
@end

NS_ASSUME_NONNULL_END
