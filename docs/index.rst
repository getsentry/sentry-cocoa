.. class:: platform-cocoa

Cocoa
=====

This is the documentation for our official clients for Cocoa (Swift and Objective-C).
Starting with version ``3.0.0`` we've switched our interal code from Swift to Objective-C
to maximize compatiblity. Also we trimmed the public API of our sdk to a minimum.
Some of the lesser used features that where present before are gone now, check out  :ref:`migration` or :ref:`advanced` for details.

Installation
------------

The SDK can be installed using `CocoaPods
<http://cocoapods.org>`__ or `Carthage
<https://github.com/Carthage/Carthage>`__.
This is the recommended client for both Swift and Objective-C.

We recommend installing Sentry with CocoaPods.

To integrate Sentry into your Xcode project using CocoaPods, specify
it in your `Podfile`:

.. sourcecode:: ruby

    source 'https://github.com/CocoaPods/Specs.git'
    platform :ios, '8.0'
    use_frameworks!

    target 'YourApp' do
        pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '###SENTRY_COCOA_TAG###'
    end

If you want to use Sentry without KSCrash you can just remove it from the subspecs.
Keep in mind that if you are not using KSCrash no events will be reported whenever you app crashes.
Also some function might do nothing if they are related to KSCrash.

Afterwards run ``pod install``.  In case you encounter problems with
dependencies and you are on a newer CocoaPods you might have to run
``pod repo update`` first.

To integrate Sentry into your Xcode project using Carthage, specify
it in your `Cartfile`:

.. sourcecode:: ruby

    github "getsentry/sentry-cocoa" "###SENTRY_COCOA_TAG###"

Run ``carthage update`` to download the framework and drag the built
`Sentry.framework` into your Xcode project.

*Please note that for Carthage we had to bundle KSCrash into the ``Sentry.framework`` to make everything work.  So you will always get KSCrash with Sentry when using Carthage.*

We also provide a prebuilt version for every release which can be downloaded at `releases on github
<https://github.com/getsentry/sentry-cocoa/releases>`__.

Configuration
-------------

To use the client, change your AppDelegate's `application` method to
instantiate the Sentry client:

.. sourcecode:: swift

    import Sentry

    func application(application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        // Create a Sentry client and start crash handler
        do {
            Client.shared = try Client(dsn: "___DSN___")
            try Client.shared?.startCrashHandler()
        } catch let error {
            print("\(error)")
            // Wrong DSN or KSCrash not installed
        }

        return true
    }

If you prefer to use Objective-C you can do so like this:

.. sourcecode:: objc

    #import <Sentry/Sentry.h>

    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"___DSN___" didFailWithError:&error];
    SentryClient.sharedClient = client;
    [SentryClient.sharedClient startCrashHandlerWithError:&error];
    if (nil != error) {
        NSLog(@"%@", error);
    }

*Note that if you call ``startCrashHandler`` will only catch errors if KSCrash is present.*

.. _sentry-cocoa-debug-symbols:

Debug Symbols
-------------

Before you can start capturing crashes you will need to tell Sentry about the debug
information by uploading dSYM files.  Depending on your setup this can be
done in different ways:

*   :ref:`dsym-with-bitcode`
*   :ref:`dsym-without-bitcode`

Testing a Crash
---------------

If you would like to test the crash reporting you will need to cause a crash. While, the seemingly obvious method
would be make it crash on launch, this will not give the Sentry client a chance
to actually submit the crash report. Instead, we recommend triggering a crash
from a button tap.

You can use the following methods to cause a crash:

*   Swift:

    .. sourcecode:: swift

        Client.shared?.crash()

*   Objective-C:

    .. sourcecode:: objc

        [SentryClient.sharedClient crash];

*Note that if you crash with a debugger attached nothing will happen.*

Crashes are only submitted upon re-launching the
application. To test the crashing, close the app and launch it again from the
springboard.

Deep Dive
---------

.. toctree::
   :maxdepth: 2

   migration
   dsym
   advanced
