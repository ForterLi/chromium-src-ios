// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/crash_report/crash_reporter_breadcrumb_observer.h"

#import "base/strings/sys_string_conversions.h"
#import "base/test/ios/wait_util.h"
#include "base/test/task_environment.h"
#include "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#include "ios/chrome/browser/crash_report/breadcrumbs/breadcrumb_manager.h"
#include "ios/chrome/browser/crash_report/breadcrumbs/breadcrumb_manager_keyed_service.h"
#include "ios/chrome/browser/crash_report/breadcrumbs/breadcrumb_manager_keyed_service_factory.h"
#import "ios/chrome/browser/crash_report/breakpad_helper.h"
#include "ios/chrome/browser/crash_report/crash_report_helper.h"
#import "ios/chrome/test/ocmock/OCMockObject+BreakpadControllerTesting.h"
#import "ios/testing/scoped_block_swizzler.h"
#include "testing/gtest/include/gtest/gtest.h"
#import "testing/gtest_mac.h"
#include "testing/platform_test.h"
#import "third_party/breakpad/breakpad/src/client/ios/BreakpadController.h"
#import "third_party/ocmock/OCMock/OCMock.h"
#include "third_party/ocmock/gtest_support.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// Returns an OCMArg validator which checks that the parameter value is a string
// containing |count| occurances of |substring|.
id StringParameterValidatorWithCountOfSubstring(NSUInteger count,
                                                NSString* substring) {
  return [OCMArg checkWithBlock:^(id value) {
    if (![value isKindOfClass:[NSString class]]) {
      return NO;
    }
    NSError* error = nil;
    NSRegularExpression* regex = [NSRegularExpression
        regularExpressionWithPattern:substring
                             options:NSRegularExpressionCaseInsensitive
                               error:&error];
    if (error) {
      return NO;
    }
    return count == [regex
                        numberOfMatchesInString:value
                                        options:0
                                          range:NSMakeRange(0, [value length])];
  }];
}
}

// Tests that CrashReporterBreadcrumbObserver attaches observed breadcrumb
// events to crash reports.
class CrashReporterBreadcrumbObserverTest : public PlatformTest {
 public:
  void SetUp() override {
    PlatformTest::SetUp();

    TestChromeBrowserState::Builder test_cbs_builder;
    chrome_browser_state_ = test_cbs_builder.Build();

    mock_breakpad_controller_ =
        [OCMockObject mockForClass:[BreakpadController class]];

    // Swizzle +[BreakpadController sharedInstance] to return
    // |mock_breakpad_controller_| instead of the normal singleton instance.
    id implementation_block = ^BreakpadController*(id self) {
      return mock_breakpad_controller_;
    };
    breakpad_controller_shared_instance_swizzler_.reset(new ScopedBlockSwizzler(
        [BreakpadController class], @selector(sharedInstance),
        implementation_block));
  }

  void TearDown() override {
    [[mock_breakpad_controller_ stub] stop];
    breakpad_helper::SetEnabled(false);
    PlatformTest::TearDown();
  }

 protected:
  id mock_breakpad_controller_;
  std::unique_ptr<ScopedBlockSwizzler>
      breakpad_controller_shared_instance_swizzler_;

  base::test::TaskEnvironment task_environment_;
  std::unique_ptr<TestChromeBrowserState> chrome_browser_state_;
};

// Tests that breadcrumb events logged to a single BreadcrumbManagerKeyedService
// are collected by the CrashReporterBreadcrumbObserver and attached to crash
// reports.
TEST_F(CrashReporterBreadcrumbObserverTest, EventsAttachedToCrashReport) {
  [[mock_breakpad_controller_ expect] start:NO];
  breakpad_helper::SetEnabled(true);

  BreadcrumbManagerKeyedService* breadcrumb_service =
      BreadcrumbManagerKeyedServiceFactory::GetForBrowserState(
          chrome_browser_state_.get());
  CrashReporterBreadcrumbObserver* crash_reporter_breadcrumb_observer =
      [[CrashReporterBreadcrumbObserver alloc] init];
  crash_reporter_breadcrumb_observer.breadcrumbsKeyCount =
      breakpad::kBreadcrumbsKeyCount;
  [crash_reporter_breadcrumb_observer
      observeBreadcrumbManagerService:breadcrumb_service];

  id breadcrumbs_param_vaidation_block = [OCMArg checkWithBlock:^(id value) {
    if (![value isKindOfClass:[NSString class]]) {
      return NO;
    }
    std::list<std::string> events = breadcrumb_service->GetEvents(0);
    std::string expected_breadcrumbs;
    for (const auto& event : events) {
      expected_breadcrumbs += event + "\n";
    }
    return
        [value isEqualToString:base::SysUTF8ToNSString(expected_breadcrumbs)];
  }];
  NSString* key = [NSString stringWithFormat:breakpad_helper::kBreadcrumbs, 0];
  [[mock_breakpad_controller_ expect]
      addUploadParameter:breadcrumbs_param_vaidation_block
                  forKey:key];

  breadcrumb_service->AddEvent(std::string("Breadcrumb Event"));
  EXPECT_OCMOCK_VERIFY(mock_breakpad_controller_);
}

// Tests that breadcrumb are spit into multiple product data keys.
TEST_F(CrashReporterBreadcrumbObserverTest, MultipleKeysAttachedToCrashReport) {
  [[mock_breakpad_controller_ expect] start:NO];
  breakpad_helper::SetEnabled(true);

  BreadcrumbManagerKeyedService* breadcrumb_service =
      BreadcrumbManagerKeyedServiceFactory::GetForBrowserState(
          chrome_browser_state_.get());
  CrashReporterBreadcrumbObserver* crash_reporter_breadcrumb_observer =
      [[CrashReporterBreadcrumbObserver alloc] init];
  crash_reporter_breadcrumb_observer.breadcrumbsKeyCount =
      breakpad::kBreadcrumbsKeyCount;
  [crash_reporter_breadcrumb_observer
      observeBreadcrumbManagerService:breadcrumb_service];

  int time_size = strlen("00:00 ");
  int linebreak_size = strlen("\n");
  int breadcrumb_size = kMaxProductDataLength - time_size - linebreak_size;
  std::string value1 = base::StringPrintf("%0*d", breadcrumb_size, 1);
  id validation_block1 = [OCMArg checkWithBlock:^(id value) {
    EXPECT_NSEQ(
        base::SysUTF8ToNSString(value1),
        [value substringWithRange:NSMakeRange(time_size, breadcrumb_size)]);
    return YES;
  }];
  NSString* key0 = [NSString stringWithFormat:breakpad_helper::kBreadcrumbs, 0];
  [[mock_breakpad_controller_ expect] addUploadParameter:validation_block1
                                                  forKey:key0];
  breadcrumb_service->AddEvent(value1);

  std::string value2 = base::StringPrintf("%0*d", breadcrumb_size, 2);
  id validation_block2 = [OCMArg checkWithBlock:^(id value) {
    EXPECT_NSEQ(
        base::SysUTF8ToNSString(value2),
        [value substringWithRange:NSMakeRange(time_size, breadcrumb_size)]);
    return YES;
  }];
  NSString* key1 = [NSString stringWithFormat:breakpad_helper::kBreadcrumbs, 1];
  [[mock_breakpad_controller_ expect] addUploadParameter:validation_block2
                                                  forKey:key0];
  [[mock_breakpad_controller_ expect] addUploadParameter:validation_block1
                                                  forKey:key1];
  breadcrumb_service->AddEvent(value2);
  EXPECT_OCMOCK_VERIFY(mock_breakpad_controller_);
}

// Tests that breadcrumbs string is cut when it does not fit into 2 product data
// keys.
TEST_F(CrashReporterBreadcrumbObserverTest, ProductDataOverflow) {
  [[mock_breakpad_controller_ expect] start:NO];
  breakpad_helper::SetEnabled(true);

  BreadcrumbManagerKeyedService* breadcrumb_service =
      BreadcrumbManagerKeyedServiceFactory::GetForBrowserState(
          chrome_browser_state_.get());
  CrashReporterBreadcrumbObserver* crash_reporter_breadcrumb_observer =
      [[CrashReporterBreadcrumbObserver alloc] init];
  // Testing with 2 keys requires less code and complexity.
  crash_reporter_breadcrumb_observer.breadcrumbsKeyCount = 2;
  [crash_reporter_breadcrumb_observer
      observeBreadcrumbManagerService:breadcrumb_service];

  int time_size = strlen("00:00 ");
  int linebreak_size = strlen("\n");
  int breadcrumb_size = kMaxProductDataLength - time_size - linebreak_size;
  std::string value1 = base::StringPrintf("%0*d", breadcrumb_size, 1);
  id validation_block1 = [OCMArg checkWithBlock:^(id value) {
    EXPECT_NSEQ(
        base::SysUTF8ToNSString(value1),
        [value substringWithRange:NSMakeRange(time_size, breadcrumb_size)]);
    return YES;
  }];
  NSString* key0 = [NSString stringWithFormat:breakpad_helper::kBreadcrumbs, 0];
  [[mock_breakpad_controller_ expect] addUploadParameter:validation_block1
                                                  forKey:key0];
  breadcrumb_service->AddEvent(value1);

  std::string value2 = base::StringPrintf("%0*d", breadcrumb_size, 2);
  id validation_block2 = [OCMArg checkWithBlock:^(id value) {
    EXPECT_NSEQ(
        base::SysUTF8ToNSString(value2),
        [value substringWithRange:NSMakeRange(time_size, breadcrumb_size)]);
    return YES;
  }];
  NSString* key1 = [NSString stringWithFormat:breakpad_helper::kBreadcrumbs, 1];
  [[mock_breakpad_controller_ expect] addUploadParameter:validation_block2
                                                  forKey:key0];
  [[mock_breakpad_controller_ expect] addUploadParameter:validation_block1
                                                  forKey:key1];
  breadcrumb_service->AddEvent(value2);

  // |value1| will be cut off as overflow.
  std::string value3 = base::StringPrintf("%0*d", breadcrumb_size, 3);
  id validation_block3 = [OCMArg checkWithBlock:^(id value) {
    EXPECT_NSEQ(
        base::SysUTF8ToNSString(value3),
        [value substringWithRange:NSMakeRange(time_size, breadcrumb_size)]);
    return YES;
  }];
  [[mock_breakpad_controller_ expect] addUploadParameter:validation_block3
                                                  forKey:key0];
  [[mock_breakpad_controller_ expect] addUploadParameter:validation_block2
                                                  forKey:key1];
  breadcrumb_service->AddEvent(value3);

  EXPECT_OCMOCK_VERIFY(mock_breakpad_controller_);
}

// Tests that breadcrumb events logged to multiple BreadcrumbManagerKeyedService
// instances are collected by the CrashReporterBreadcrumbObserver and attached
// to crash reports.
TEST_F(CrashReporterBreadcrumbObserverTest,
       MultipleBrowserStatesAttachedToCrashReport) {
  [[mock_breakpad_controller_ expect] start:NO];
  breakpad_helper::SetEnabled(true);

  const std::string event = std::string("Breadcrumb Event");
  NSString* event_nsstring = base::SysUTF8ToNSString(event);

  BreadcrumbManagerKeyedService* breadcrumb_service =
      BreadcrumbManagerKeyedServiceFactory::GetForBrowserState(
          chrome_browser_state_.get());
  CrashReporterBreadcrumbObserver* crash_reporter_breadcrumb_observer =
      [[CrashReporterBreadcrumbObserver alloc] init];
  crash_reporter_breadcrumb_observer.breadcrumbsKeyCount =
      breakpad::kBreadcrumbsKeyCount;
  [crash_reporter_breadcrumb_observer
      observeBreadcrumbManagerService:breadcrumb_service];

  NSString* key = [NSString stringWithFormat:breakpad_helper::kBreadcrumbs, 0];
  [[mock_breakpad_controller_ expect]
      addUploadParameter:StringParameterValidatorWithCountOfSubstring(
                             1, event_nsstring)
                  forKey:key];
  breadcrumb_service->AddEvent(event);

  ChromeBrowserState* otr_browser_state =
      chrome_browser_state_->GetOffTheRecordChromeBrowserState();
  BreadcrumbManagerKeyedService* otr_breadcrumb_service =
      BreadcrumbManagerKeyedServiceFactory::GetForBrowserState(
          otr_browser_state);
  [crash_reporter_breadcrumb_observer
      observeBreadcrumbManagerService:otr_breadcrumb_service];

  [[mock_breakpad_controller_ expect]
      addUploadParameter:StringParameterValidatorWithCountOfSubstring(
                             2, event_nsstring)
                  forKey:key];
  otr_breadcrumb_service->AddEvent(event);

  TestChromeBrowserState::Builder test_cbs_builder;
  std::unique_ptr<TestChromeBrowserState> chrome_browser_state_2 =
      test_cbs_builder.Build();
  BreadcrumbManagerKeyedService* breadcrumb_service_2 =
      BreadcrumbManagerKeyedServiceFactory::GetForBrowserState(
          chrome_browser_state_2.get());
  [crash_reporter_breadcrumb_observer
      observeBreadcrumbManagerService:breadcrumb_service_2];

  [[mock_breakpad_controller_ expect]
      addUploadParameter:StringParameterValidatorWithCountOfSubstring(
                             3, event_nsstring)
                  forKey:key];
  breadcrumb_service_2->AddEvent(event);

  EXPECT_OCMOCK_VERIFY(mock_breakpad_controller_);

  // Manually clear observer reference before the Browsers are deconstructed.
  crash_reporter_breadcrumb_observer = nil;
}
