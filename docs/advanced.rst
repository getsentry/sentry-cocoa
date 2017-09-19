.. _advanced:

Advanced Usage
==============

With Senty ``3.0.0`` we introduced some breaking changes.
We removed some of the functions that were available before and added a few
for more flexibility.
KSCrash is optional with ``3.0.0`` so if you call ``startCrashHandler`` it will only
do something if you also have KSCrash installed.
We've switched our code from Swift to Objective-C, so the code below shows mostly
Swift code. Even though Sentry is perfectly compatible with Objective-C all classes
are prefixed with `Sentry`.

Capturing uncaught exceptions on macOS
--------------------------------------

By default macOS application do not crash whenever an uncaught exception occurs.
There are some additional steps you have to take to make this work with Sentry.
You have to open the applications ``Info.plist`` file and look for ``Principal class``.
The content of it which should be ``NSApplication`` should be replaced with ``SentryCrashExceptionApplication``.

Sending Events
--------------

Sending a basic event can be done with `send`.

.. sourcecode:: swift

    let event = Event(level: .debug)
    event.message = "Test Message"
    Client.shared?.send(event: event) { (error) in
        // Optional callback after event has been send
    }

If more detailed information is required, `Event` has many more properties to be
filled.

.. sourcecode:: swift

    let event = Event(level: .debug)
    event.message = "Test Message"
    event.environment = "staging"
    event.extra = ["ios": true]
    Client.shared?.send(event: event)

Client Information
------------------

A user, tags, and extra information can be stored on a `Client`.
This information will be sent with every event. They can be used like...

.. sourcecode:: swift

    let user = User(userId: "1234")
    user.email = "hello@sentry.io"
    user.extra = ["is_admin": true]
    Client.shared?.user = user

    Client.shared?.tags = ["iphone": "true"]

    Client.shared?.extra = [
        "my_key": 1,
        "some_other_value": "foo bar"
    ]

All of the above (`user`, `tags`, and `extra`) can be set at anytime.
Call ``Client.shared?.clearContext()`` to clear all set variables.

.. _cocoa-user-feedback:

User Feedback
-------------

The `User Feedback` feature has been removed as of version ``3.0.0``.
But if you want to show you own Controller or handle stuff after a crash you can use
our :ref:`before-serialize-event` callback.
We are now also sending a notification whenever an event has been sent.
The name of the notifcation is ``Sentry/eventSentSuccessfully`` and it contains the
serialzed event as ``userInfo``.
Additionally the Client has a new property ``Client.shared?.lastEvent`` which always
contains the most recent event.

Breadcrumbs
-----------

Breadcrumbs are used as a way to trace how an error occured. They will queue up in a`Client` and will be sent with every event.

.. sourcecode:: swift

    Client.shared?.breadcrumbs.add(Breadcrumb(level: .info, category: "test"))

The client will queue up a maximum of 50 breadcrumbs by default.
To change the maximum amout of breadcrumbs call:

.. sourcecode:: swift

    Client.shared?.breadcrumbs.maxBreadcrumbs = 100

With version `1.1.0` we added another iOS only feature which tracks breadcrumbs automatically by calling:

.. sourcecode:: swift

    Client.shared?.enableAutomaticBreadcrumbTracking()

If called this will track every action sent from a Storyboard and every `viewDidAppear` from an `UIViewController`.
We use method swizzling for this feature, so in case your app also overwrites one of these methods be sure to checkout our implementation in our repo.

.. _before-serialize-event:

Change event before sending it
------------------------------

With version `1.3.0` we added the possiblity to change an event before it will be sent to the server.
You have to set the block somewhere in you code.

.. sourcecode:: swift

    Client.shared?.beforeSerializeEvent = { event in
        event.extra = ["b": "c"]
    }

This block is meant to be used for stripping sensitive data or add additional data for every event.

Change request before sending it
--------------------------------

You can change the `NSURLRequest` before it will be send. This is helpful e.g.: for adding
additional headers to the request.

.. sourcecode:: swift

    Client.shared?.beforeSendRequest = { request in
        request.addValue("my-token", forHTTPHeaderField: "Authorization")
    }

Adding stacktrace to message
----------------------------

You can also add a Stacktrace to your event by using the `snapshotStacktrace` callback and calling `appendStacktrace` and pass the event.

`snapshotStacktrace` captures the stacktrace at the location where it's called.
After that you have to append the stacktrace to the event you want to send with `appendStacktrace`.
So for example if you want to send a simple message to the server and add the stacktrace to it you have to do this.

.. sourcecode:: swift

    Client.shared?.snapshotStacktrace {
        let event = Event(level: .debug)
        event.message = "Test Message"
        Client.shared?.appendStacktrace(to: event)
        Client.shared?.send(event: event)
    }

Event Sampling
--------------

If you are sending to many events and want to not send all events you can set the ``sampleRate`` parameter.
It's a number between 0 and 1 where when you set it to 1, all events will be sent.
Notice that ``shouldSendEvent`` will set for this.

.. sourcecode:: swift

    Client.shared?.sampleRate = 0.75 // 75% of all events will be sent
