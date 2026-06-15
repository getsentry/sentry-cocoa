@import SentryObjC;
@import XCTest;

#import <TargetConditionals.h>

#if TARGET_OS_IOS
@import UIKit;

@interface SentryObjCUserFeedbackConfigurationTests : XCTestCase
@end

@implementation SentryObjCUserFeedbackConfigurationTests

- (void)testUserFeedbackConfiguration_whenSet_shouldReturnValues
{
    // -- Arrange --
    SentryObjCUserFeedbackConfiguration *config =
        [[SentryObjCUserFeedbackConfiguration alloc] init];
    UIButton *button = [[UIButton alloc] init];

    // -- Act --
    config.animations = NO;
    config.useShakeGesture = YES;
    config.showFormForScreenshots = YES;
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    config.customButton = button;
#    pragma clang diagnostic pop
    config.tags = @{ @"feature" : @"feedback" };

    // -- Assert --
    XCTAssertFalse(config.animations);
    XCTAssertTrue(config.useShakeGesture);
    XCTAssertTrue(config.showFormForScreenshots);
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    XCTAssertEqualObjects(config.customButton, button);
#    pragma clang diagnostic pop
    XCTAssertEqualObjects([config.tags objectForKey:@"feature"], @"feedback");
}

- (void)testConfigureForm_whenCalled_shouldConfigureForm
{
    // -- Arrange --
    SentryObjCUserFeedbackConfiguration *config =
        [[SentryObjCUserFeedbackConfiguration alloc] init];
    SentryObjCUserFeedbackFormConfiguration *form =
        [[SentryObjCUserFeedbackFormConfiguration alloc] init];
    config.configureForm = ^(SentryObjCUserFeedbackFormConfiguration *configuration) {
        configuration.useSentryUser = NO;
        configuration.showBranding = NO;
        configuration.formTitle = @"Jank Report";
        configuration.messageLabel = @"Complaint";
        configuration.messagePlaceholder = @"Describe the jank";
        configuration.messageTextViewAccessibilityLabel = @"Message";
        configuration.isRequiredLabel = @"Required";
        configuration.removeScreenshotButtonLabel = @"Remove";
        configuration.removeScreenshotButtonAccessibilityLabel = @"Remove screenshot";
        configuration.isNameRequired = YES;
        configuration.showName = NO;
        configuration.nameLabel = @"Name";
        configuration.namePlaceholder = @"Your name";
        configuration.nameTextFieldAccessibilityLabel = @"Name input";
        configuration.isEmailRequired = YES;
        configuration.showEmail = NO;
        configuration.emailLabel = @"Email";
        configuration.emailPlaceholder = @"Your email";
        configuration.emailTextFieldAccessibilityLabel = @"Email input";
        configuration.submitButtonLabel = @"Send";
        configuration.submitButtonAccessibilityLabel = @"Send feedback";
        configuration.cancelButtonLabel = @"Cancel";
        configuration.cancelButtonAccessibilityLabel = @"Cancel feedback";
        configuration.unexpectedErrorText = @"Unexpected";
        configuration.validationErrorMessage = ^NSString *(
            BOOL multipleErrors) { return multipleErrors ? @"Many errors" : @"One error"; };
    };

    // -- Act --
    config.configureForm(form);

    // -- Assert --
    XCTAssertFalse(form.useSentryUser);
    XCTAssertFalse(form.showBranding);
    XCTAssertEqualObjects(form.formTitle, @"Jank Report");
    XCTAssertEqualObjects(form.messageLabel, @"Complaint");
    XCTAssertEqualObjects(form.messagePlaceholder, @"Describe the jank");
    XCTAssertEqualObjects(form.messageTextViewAccessibilityLabel, @"Message");
    XCTAssertEqualObjects(form.isRequiredLabel, @"Required");
    XCTAssertEqualObjects(form.removeScreenshotButtonLabel, @"Remove");
    XCTAssertEqualObjects(form.removeScreenshotButtonAccessibilityLabel, @"Remove screenshot");
    XCTAssertTrue(form.isNameRequired);
    XCTAssertFalse(form.showName);
    XCTAssertEqualObjects(form.nameLabel, @"Name");
    XCTAssertEqualObjects(form.namePlaceholder, @"Your name");
    XCTAssertEqualObjects(form.nameTextFieldAccessibilityLabel, @"Name input");
    XCTAssertTrue(form.isEmailRequired);
    XCTAssertFalse(form.showEmail);
    XCTAssertEqualObjects(form.emailLabel, @"Email");
    XCTAssertEqualObjects(form.emailPlaceholder, @"Your email");
    XCTAssertEqualObjects(form.emailTextFieldAccessibilityLabel, @"Email input");
    XCTAssertEqualObjects(form.submitButtonLabel, @"Send");
    XCTAssertEqualObjects(form.submitButtonAccessibilityLabel, @"Send feedback");
    XCTAssertEqualObjects(form.cancelButtonLabel, @"Cancel");
    XCTAssertEqualObjects(form.cancelButtonAccessibilityLabel, @"Cancel feedback");
    XCTAssertEqualObjects(form.unexpectedErrorText, @"Unexpected");
    XCTAssertEqualObjects(form.validationErrorMessage(NO), @"One error");
    XCTAssertEqualObjects(form.validationErrorMessage(YES), @"Many errors");
}

- (void)testConfigureTheme_whenCalled_shouldConfigureTheme
{
    // -- Arrange --
    SentryObjCUserFeedbackConfiguration *config =
        [[SentryObjCUserFeedbackConfiguration alloc] init];
    SentryObjCUserFeedbackThemeConfiguration *theme =
        [[SentryObjCUserFeedbackThemeConfiguration alloc] init];
    UIColor *foreground = UIColor.redColor;
    UIColor *background = UIColor.blueColor;
    SentryObjCUserFeedbackFormElementOutlineStyle *outlineStyle =
        [[SentryObjCUserFeedbackFormElementOutlineStyle alloc] initWithColor:UIColor.purpleColor
                                                                cornerRadius:10
                                                                outlineWidth:2];
    config.configureTheme = ^(SentryObjCUserFeedbackThemeConfiguration *configuration) {
        configuration.fontFamily = @"Helvetica";
        configuration.foreground = foreground;
        configuration.background = background;
        configuration.submitForeground = UIColor.whiteColor;
        configuration.submitBackground = UIColor.greenColor;
        configuration.buttonForeground = UIColor.orangeColor;
        configuration.buttonBackground = UIColor.clearColor;
        configuration.errorColor = UIColor.redColor;
        configuration.outlineStyle = outlineStyle;
        configuration.inputBackground = UIColor.lightGrayColor;
        configuration.inputForeground = UIColor.darkTextColor;
    };

    // -- Act --
    config.configureTheme(theme);

    // -- Assert --
    XCTAssertEqualObjects(theme.fontFamily, @"Helvetica");
    XCTAssertEqualObjects(theme.foreground, foreground);
    XCTAssertEqualObjects(theme.background, background);
    XCTAssertEqualObjects(theme.submitForeground, UIColor.whiteColor);
    XCTAssertEqualObjects(theme.submitBackground, UIColor.greenColor);
    XCTAssertEqualObjects(theme.buttonForeground, UIColor.orangeColor);
    XCTAssertEqualObjects(theme.buttonBackground, UIColor.clearColor);
    XCTAssertEqualObjects(theme.errorColor, UIColor.redColor);
    XCTAssertEqualObjects(theme.outlineStyle.color, UIColor.purpleColor);
    XCTAssertEqual(theme.outlineStyle.cornerRadius, 10);
    XCTAssertEqual(theme.outlineStyle.outlineWidth, 2);
    XCTAssertEqualObjects(theme.inputBackground, UIColor.lightGrayColor);
    XCTAssertEqualObjects(theme.inputForeground, UIColor.darkTextColor);
}

- (void)testCallbacks_whenCalled_shouldInvokeBlocks
{
    // -- Arrange --
    SentryObjCUserFeedbackConfiguration *config =
        [[SentryObjCUserFeedbackConfiguration alloc] init];
    __block NSUInteger callbackCount = 0;
    config.onFormOpen = ^{ callbackCount += 1; };
    config.onFormClose = ^{ callbackCount += 1; };
    config.onSubmitSuccess = ^(NSDictionary<NSString *, id> *info) {
        if ([[info objectForKey:@"message"] isEqual:@"hello"]) {
            callbackCount += 1;
        }
    };
    config.onSubmitError = ^(NSError *error) {
        if (error.code == 1) {
            callbackCount += 1;
        }
    };

    // -- Act --
    config.onFormOpen();
    config.onFormClose();
    config.onSubmitSuccess(@{ @"message" : @"hello" });
    config.onSubmitError([NSError errorWithDomain:@"io.sentry.test" code:1 userInfo:nil]);

    // -- Assert --
    XCTAssertEqual(callbackCount, 4U);
}

- (void)testOptionsConfigureUserFeedback_whenCalled_shouldConfigureUserFeedback
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    SentryObjCUserFeedbackConfiguration *config =
        [[SentryObjCUserFeedbackConfiguration alloc] init];
    options.configureUserFeedback
        = ^(SentryObjCUserFeedbackConfiguration *configuration) { configuration.animations = NO; };

    // -- Act --
    options.configureUserFeedback(config);

    // -- Assert --
    XCTAssertFalse(config.animations);
}

@end

#endif
