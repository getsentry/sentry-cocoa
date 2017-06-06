.. _migration:

Migration Guide
===============

Upgrade from 2.x.x to 3.0.x
---------------------------

*   CocoaPods
    Make sure to update your Podfile to include ``:subspecs => ['Core', 'KSCrash']``

    .. sourcecode:: ruby

        source 'https://github.com/CocoaPods/Specs.git'
        platform :ios, '8.0'
        use_frameworks!

        target 'YourApp' do
            pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :subspecs => ['Core', 'KSCrash'], :tag => '###SENTRY_COCOA_TAG###'
        end

*   Carthage
    Make sure to remove KSCrash, we bundled KSCrash into Sentry in order to make it work.

    .. sourcecode:: ruby

        github "getsentry/sentry-cocoa" "###SENTRY_COCOA_TAG###"

*   Public API
    We changed alot of the public API, please checkout :ref:`advanced` for more examples about that.



