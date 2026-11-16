// Keep this image pure C and load it only through dlopen in the test. Swift/ObjC metadata or
// launch-time linking can keep an image mapped after the test closes its last owned reference.
__attribute__((visibility("default"))) int sentry_unloadable_image(void);

int
sentry_unloadable_image(void)
{
    return 42;
}
