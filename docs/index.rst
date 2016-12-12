.. class:: platform-cocoa

Cocoa
=====

This is the documentation for our official clients for Cocoa (Swift and Objective-C).

Installation
------------

The client (SentrySwift) can be installed using `CocoaPods
<http://cocoapods.org>`__ or `Carthage
<https://github.com/Carthage/Carthage>`__.  This is the recommended client
for both Swift and Objective-C.  If you need support for old versions of
iOS that do not support Swift you can use our alternative `Sentry-Objc
<https://github.com/getsentry/sentry-objc>`_ client.

To integrate SentrySwift into your Xcode project using CocoaPods, specify
it in your `Podfile`:

.. sourcecode:: ruby

    source 'https://github.com/CocoaPods/Specs.git'
    platform :ios, '8.0'
    use_frameworks!

    target 'YourApp' do
        pod 'SentrySwift', :git => 'https://github.com/getsentry/sentry-swift.git', :tag => '###SENTRY_SWIFT_TAG###'
    end

Afterwards run ``pod install``.  In case you encounter problems with
dependencies and you are on a newer CocoaPods you might have to run
``pod repo update`` first.

In case your project still uses Swift 2.3 you can add these lines at the end of your Podfile which tells your Pods to use Swift 2.3.

.. sourcecode:: ruby

    post_install do |installer|
      installer.pods_project.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '2.3'
        config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'NO'
      end
    end

To integrate SentrySwift into your Xcode project using Carthage, specify
it in your `Cartfile`:

.. sourcecode:: ruby

    github "getsentry/sentry-swift" "###SENTRY_SWIFT_TAG###"

Run ``carthage update`` to build the framework and drag the built
`SentrySwift.framework` and `KSCrash.framework` into your Xcode project.

We also provide a prebuilt version for every release which you can download in the `releases section on github
<https://github.com/getsentry/sentry-swift/releases>`__.

Configuration
-------------

To use the client, change your AppDelegate's `application` method to
instantiate the Sentry client:

.. sourcecode:: swift

    import SentrySwift;

    func application(application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        // Create a Sentry client and start crash handler
        SentryClient.shared = SentryClient(dsnString: "___DSN___")
        SentryClient.shared?.startCrashHandler()
        
        return true
    }

If you do not want to send events in a debug build, you can wrap the above
code in something like this:

.. sourcecode:: swift

    // Create a Sentry client and start crash handler when not in debug
    if !DEBUG {
        SentryClient.shared = SentryClient(dsnString: "___DSN___")
        SentryClient.shared?.startCrashHandler()
    }

If you prefer to use Objective-C you can do so like this:

.. sourcecode:: objc

    @import SentrySwift;

    [SentryClient setShared:[[SentryClient alloc] initWithDsnString:@"___DSN___"]];
    [[SentryClient shared] startCrashHandler];

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

        SentryClient.shared?.crash()

*   Objective-C:

    .. sourcecode:: objc

        [[SentryClient shared] crash];

*Note that if you crash with a debugger attached nothing will happen.*

Crashes are only submitted upon re-launching the
application. To test the crashing, close the app and launch it again from the
springboard.

Deep Dive
---------

.. toctree::
   :maxdepth: 2

   dsym
   advanced
