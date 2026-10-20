#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString *_Nonnull (^DFZRequestHandler)(NSData *request, BOOL *ok);

// Unix socket protocol: one `\n`-terminated JSON request per connection, answered
// with `ok\n<payload>` or `err\n<message>`, then the connection is closed.
@interface DFZServer : NSObject
- (instancetype)initWithPath:(NSString *)path handler:(DFZRequestHandler)handler;
- (BOOL)start:(NSString *_Nullable *_Nullable)error;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
