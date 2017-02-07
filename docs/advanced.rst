Advanced Usage
==============

Here are some advanced topics:


Sending Messages
----------------

Sending a basic message (no stacktrace) can be done with `captureMessage`.

.. sourcecode:: swift

    SentryClient.shared?.captureMessage("TEST 1 2 3", level: .Debug)

If more detailed information is required, `Event` has a large constructor
that allows for passing in of all the information or a `build` function
can be called to build the `Event` object like below.

.. sourcecode:: swift

    let event = Event.build("TEST 1 2 3") {
        $0.level = .Debug
        $0.tags = ["context": "production"]
        $0.extra = [
            "my_key": 1,
            "some_other_value": "foo bar"
        ]
    }
    SentryClient.shared?.captureEvent(event)

Client Information
------------------

A user, tags, and extra information can be stored on a `SentryClient`.
This information will get sent with every message/exception in which that
`SentryClient` sends up the Sentry. They can be used like...

.. sourcecode:: swift

    SentryClient.shared?.user = User(id: "3",
        email: "example@example.com",
        username: "Example",
        extra: ["is_admin": false]
    )

    SentryClient.shared?.tags = [
        "context": "production"
    ]

    SentryClient.shared?.extra = [
        "my_key": 1,
        "some_other_value": "foo bar"
    ]

All of the above (`user`, `tags`, and `extra`) can all be set at anytime
and can also be set to `nil` to clear.

.. _cocoa-user-feedback:

User Feedback (iOS only feature)
--------------------------------

You can activate the User Feedback feature by simply calling `enableUserFeedbackAfterFatalEvent`, which will then in case of an `Fatal` event call a delegate method where you can present the provided User Feedback viewcontroller.

.. sourcecode:: swift

    SentryClient.shared?.enableUserFeedbackAfterFatalEvent()
    SentryClient.shared?.delegate = self

Additionally you have to set the `delegate` and implement the `SentryClientUserFeedbackDelegate` protocol. It is your responsability to present the UserFeedback viewcontroller according to your needs, below you'll find the code to present the viewcontroller modally.

.. sourcecode:: swift

    // MARK: SentryClientUserFeedbackDelegate

    func userFeedbackReady() {
        if let viewControllers = SentryClient.shared?.userFeedbackControllers() {
            presentViewController(viewControllers.navigationController, animated: true, completion: nil)
        }
    }

    func userFeedbackSent() {
        // Will be called after userFeedback has been sent
    }

You can pass a `UserFeedbackViewModel` to the `enableUserFeedbackAfterFatalEvent` to customize the labels of the controller. Alternatively you'll get the complete viewcontrollers with this function `SentryClient.shared?.userFeedbackControllers()`.

Please take a look at our example projects if you need more details on how to integrate it.


Breadcrumbs
-----------

Breadcrumbs are used as a way to trace how an error occured. They will queue up on a `SentryClient` and will be sent up with the next event.

.. sourcecode:: swift

    SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "navigation", to: "point b", from: "point a"))

The client will queue up a maximum of 50 breadcrumbs by default.
To change the maximum amout of breadcrumbs call:

.. sourcecode:: swift

    SentryClient.shared?.breadcrumbs.maxCrumbs = 100

With version `1.1.0` we added another iOS only feature which tracks breadcrumbs automatically by calling:

.. sourcecode:: swift

    SentryClient.shared?.enableAutomaticBreadcrumbTracking()

If called this will track every action sent from a Storyboard and every `viewDidAppear` from an `UIViewController`.
We use method swizzling for this feature, so in case your app also overwrites one of these methods be sure to checkout our implementation in our repo.


Change event before sending it
------------------------------

With version `1.3.0` we added the possiblity to change an event before it gets send to the server.
You have to set the block somewhere in you code.

.. sourcecode:: swift

    SentryClient.shared?.beforeSendEventBlock = {
        // $0 == Event
        $0.message = "Add" + $0.message
    }

This block is meant to be used for stripping sensitive data or add additional data for every event.

Adding stacktrace to message
----------------------------

In version `1.3.0` we also added a new function called: `SentryClient.shared?.snapshotStacktrace()`

This function captures the stacktrace at the location where its called. So for example if you want to send a simple message to the server and add the stacktrace to it you have to do this.

.. sourcecode:: swift

    // This is somewhere in you setup code define the beforeSendEventBlock
    SentryClient.shared?.beforeSendEventBlock = {
        // This function fetches the snapshot of the stacktrace and adds it to the event
        // Be aware that this function only sets the stacktrace if its no real crash
        // So it will never overwrite an existing
        $0.fetchStacktrace()
    }

    ......

    // Somewhere where you want to capture the stacktrace and send a simple message
    SentryClient.shared?.snapshotStacktrace()
    SentryClient.shared?.captureMessage("This is my simple message but with a stacktrace")
