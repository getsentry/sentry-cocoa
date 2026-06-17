#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @return YES if the process has a debugger attached.
 * @see https://developer.apple.com/library/archive/qa/qa1361/_index.html
 */
BOOL isDebugging(void);

/**
 * @return YES if the process is running in a simulator.
 * @see https://stackoverflow.com/a/45329149
 */
BOOL isSimulator(void);

NS_ASSUME_NONNULL_END
