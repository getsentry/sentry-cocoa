//
//  ViewController.m
//  ObjCExample
//
//  Created by Josh Holtz on 3/16/16.
//  Copyright © 2016 RokkinCat. All rights reserved.
//

#import "ViewController.h"

// Step 1: Import the SentrySwift framework
@import SentrySwift;

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	// Step 1.5: Set logging level to your liking
	[SentryClient setLogLevel:SentryLogDebug];
	
	// Step 2: Initialize a SentryClient with your DSN
	// The DSN is in your Sentry project's settings
	[SentryClient setShared:[[SentryClient alloc] initWithDsnString:@"your-dsn"]];
	
	// OPTIONAL (but super useful)
	// Step 3: Set and start the crash listener using SentryKSCrashHandler
	// This uses KSCrash under the hood
	[[SentryClient shared] startCrashHandler];
	
	// OPTIONAL (but also useful)
	// Step 4: Set any user or global information to be sent up with every exception/message
	// This is optional and can also be done at anytime (so when a user logs in/out)
	[SentryClient shared].user = [[User alloc] initWithId:@"3" email:@"example@example.com" username:@"Example" extra:@{@"is_admin": @NO}];

	// A map or list of tags for this event.
	[SentryClient shared].tags = @{@"environment": @"production"};
	
	// An arbitrary mapping of additional metadata to store with the event
	[SentryClient shared].extra = @{
									@"a_thing": @3,
									@"some_things": @[@"green", @"red"],
									@"foobar": @{@"foo": @"bar"}
									};
    
    // Step 5: Add breadcrumbs to help you debug errors
    Breadcrumb *bcStart = [[Breadcrumb alloc] initWithCategory:@"test" timestamp:[NSDate new] message:nil type:nil level:SentrySeverityDebug data:@{@"navigation": @"app start"}];
    Breadcrumb *bcMain = [[Breadcrumb alloc] initWithCategory:@"test" timestamp:[NSDate new] message:nil type:nil level:SentrySeverityDebug data:@{@"navigation": @"main screen"}];
    [[SentryClient shared].breadcrumbs add:bcStart];
    [[SentryClient shared].breadcrumbs add:bcMain];
	
	// Step 6: Don't make your app perfect so that you can get a crash ;)
	// See the really bad "onClickBreak" function on how to do that
}

- (IBAction)onClickBreak:(id)sender {
	NSMutableArray *someArray = @[].mutableCopy;
	[someArray addObject:nil];
}

- (IBAction)onClickMessage:(id)sender {
	[[SentryClient shared] captureMessage:@"Some plain message from ObjC" level:SentrySeverityInfo];
}

- (IBAction)onClickComplexMessage:(id)sender {
	Event *event = [[Event alloc] init:@"Some message from ObjC"
							 timestamp:[NSDate date]
								 level:SentrySeverityFatal
								logger:nil
							   culprit:nil
							serverName:nil
							   release:nil
								  tags:nil
							   modules:nil
								 extra:nil
						   fingerprint:nil
								  user:nil
							 exception:nil
					  appleCrashReport:nil];
	
	[[SentryClient shared] captureEvent:event];
}

- (IBAction)onClickError:(id)sender {
    NSError *error = [[NSError alloc] initWithDomain:@"test.domain" code:-1 userInfo:nil];
    
    Event *event = [[Event alloc] init:error.domain
                             timestamp:[NSDate date]
                                 level:SentrySeverityError
                                logger:nil
                               culprit:nil
                            serverName:nil
                               release:nil
                                  tags:nil
                               modules:nil
                                 extra:nil
                           fingerprint:nil
                                  user:nil
							 exception:nil
                      appleCrashReport:nil];
    
    [[SentryClient shared] captureEvent:event];
}



@end
