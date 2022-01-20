// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/exception/src/Exception.h"

#include <stdexcept>

TEST(ExceptionTest, TestUsingExceptionHandlerDoesntRaiseException) {
    try {
        specto::internal::handleCppException([&] { throw std::runtime_error("Error!"); }, [&]() {});
    } catch (...) {
        FAIL() << "Did not expect exception to be thrown";
    }
}

TEST(ExceptionTest, TestExceptionHandlerMacroStillThrowsWhenInTest) {
    EXPECT_THROW(SPECTO_HANDLE_CPP_EXCEPTION({ throw std::runtime_error("Error!"); }),
                 std::runtime_error);
}

TEST(ExceptionTest, TestSetGetExceptionKillswitchState) {
    specto::internal::setCppExceptionKillswitch(false);
    EXPECT_FALSE(specto::internal::isCppExceptionKillswitchSet());

    specto::internal::setCppExceptionKillswitch(true);
    EXPECT_TRUE(specto::internal::isCppExceptionKillswitchSet());
}

TEST(ExceptionTest, TestNotifiesKillswitchObservers) {
    specto::internal::setCppExceptionKillswitch(false);

    bool calledObserver = false;
    specto::addCppExceptionKillswitchObserver([&] { calledObserver = true; });
    specto::internal::handleCppException([&] { throw std::runtime_error("Error!"); }, [&]() {});
    EXPECT_TRUE(calledObserver);
}

TEST(ExceptionTest, TestKillSwitchEnabledLambda) {
    specto::internal::setCppExceptionKillswitch(true);
    bool ranKillSwitchLambda = false;
    bool ranMainLambda = false;
    SPECTO_TEST_ONLY_HANDLE_CPP_EXCEPTION_IF_ALIVE({ ranMainLambda = true; },
                                                   { ranKillSwitchLambda = true; });
    EXPECT_TRUE(ranKillSwitchLambda);
    EXPECT_FALSE(ranMainLambda);
}

TEST(ExceptionTest, TestKillSwitchDisabledLambda) {
    specto::internal::setCppExceptionKillswitch(false);
    bool ranKillSwitchLambda = false;
    bool ranMainLambda = false;
    SPECTO_TEST_ONLY_HANDLE_CPP_EXCEPTION_IF_ALIVE({ ranMainLambda = true; },
                                                   { ranKillSwitchLambda = true; });
    EXPECT_FALSE(ranKillSwitchLambda);
    EXPECT_TRUE(ranMainLambda);
}
