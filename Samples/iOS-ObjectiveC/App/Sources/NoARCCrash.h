/**
 * We need to this into an extra file so we can disable ARC with the -fno-objc-arc Compiler flag.
 * Otherwise, we can't call [NSObject release].
 *
 */
void callMessageOnDeallocatedObject(void);
