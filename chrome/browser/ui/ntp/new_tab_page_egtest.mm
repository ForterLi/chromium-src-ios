// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "base/test/ios/wait_util.h"
#include "base/test/scoped_command_line.h"
#include "components/strings/grit/components_strings.h"
#include "ios/chrome/browser/chrome_url_constants.h"
#import "ios/chrome/browser/metrics/metrics_app_interface.h"
#import "ios/chrome/browser/ui/content_suggestions/ntp_home_constant.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/testing/earl_grey/app_launch_manager.h"
#import "ios/testing/earl_grey/earl_grey_test.h"
#include "net/test/embedded_test_server/embedded_test_server.h"
#include "net/test/embedded_test_server/http_request.h"
#include "net/test/embedded_test_server/http_response.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

const char kPageLoadedString[] = "Page loaded!";
const char kPageURL[] = "/test-page.html";
const char kPageTitle[] = "Page title!";
const char kInvalidNTPLocation[] = "invalid_url";

// Provides responses for redirect and changed window location URLs.
std::unique_ptr<net::test_server::HttpResponse> StandardResponse(
    const net::test_server::HttpRequest& request) {
  if (request.relative_url != kPageURL) {
    return nullptr;
  }
  std::unique_ptr<net::test_server::BasicHttpResponse> http_response =
      std::make_unique<net::test_server::BasicHttpResponse>();
  http_response->set_code(net::HTTP_OK);
  http_response->set_content("<html><head><title>" + std::string(kPageTitle) +
                             "</title></head><body>" +
                             std::string(kPageLoadedString) + "</body></html>");
  return std::move(http_response);
}

// Pauses until the history label has disappeared.  History should not show on
// incognito.
BOOL WaitForHistoryToDisappear() {
  return [[GREYCondition
      conditionWithName:@"Wait for history to disappear"
                  block:^BOOL {
                    NSError* error = nil;
                    NSString* history =
                        l10n_util::GetNSString(IDS_HISTORY_SHOW_HISTORY);
                    [[EarlGrey selectElementWithMatcher:grey_accessibilityLabel(
                                                            history)]
                        assertWithMatcher:grey_notVisible()
                                    error:&error];
                    return error == nil;
                  }] waitWithTimeout:base::test::ios::kWaitForUIElementTimeout];
}

}  // namespace

@interface NewTabPageTestCase : ChromeTestCase
@property(nonatomic, assign) BOOL histogramTesterSet;
@end

@implementation NewTabPageTestCase

- (void)tearDown {
  [self releaseHistogramTester];
  [super tearDown];
}

- (void)setupHistogramTester {
  if (self.histogramTesterSet) {
    return;
  }
  self.histogramTesterSet = YES;
  GREYAssertNil([MetricsAppInterface setupHistogramTester],
                @"Cannot setup histogram tester.");
}

- (void)releaseHistogramTester {
  if (!self.histogramTesterSet) {
    return;
  }
  self.histogramTesterSet = NO;
  GREYAssertNil([MetricsAppInterface releaseHistogramTester],
                @"Cannot reset histogram tester.");
}

#pragma mark - Helpers

// Add the NTP Location policy to the app's launch configuration.
- (void)configureAppWithNTPLocation:(std::string)ntpLocation {
  AppLaunchConfiguration config;
  config.additional_args.push_back("-NTPLocation");
  config.additional_args.push_back(ntpLocation);
  config.relaunch_policy = ForceRelaunchByKilling;
  [[AppLaunchManager sharedManager] ensureAppLaunchedWithConfiguration:config];
}

#pragma mark - Tests

// Tests that all items are accessible on the most visited page.
- (void)testAccessibilityOnMostVisited {
  [ChromeEarlGrey verifyAccessibilityForCurrentScreen];
}

// Tests the metrics are reported correctly.
- (void)testNTPMetrics {
  self.testServer->RegisterRequestHandler(
      base::BindRepeating(&StandardResponse));
  GREYAssertTrue(self.testServer->Start(), @"Test server failed to start.");
  const GURL pageURL = self.testServer->GetURL(kPageURL);
  [ChromeEarlGrey closeAllTabs];

  // Open and close an NTP.
  [self setupHistogramTester];
  NSError* error =
      [MetricsAppInterface expectTotalCount:0
                               forHistogram:@"NewTabPage.TimeSpent"];
  GREYAssertNil(error, error.description);
  [ChromeEarlGrey openNewTab];
  [ChromeEarlGrey closeAllTabs];
  error = [MetricsAppInterface expectTotalCount:1
                                   forHistogram:@"NewTabPage.TimeSpent"];
  GREYAssertNil(error, error.description);
  [self releaseHistogramTester];

  // Open an incognito NTP and close it.
  [ChromeEarlGrey closeAllTabs];
  [self setupHistogramTester];
  error = [MetricsAppInterface expectTotalCount:0
                                   forHistogram:@"NewTabPage.TimeSpent"];
  GREYAssertNil(error, error.description);
  [ChromeEarlGrey openNewIncognitoTab];
  [ChromeEarlGrey closeAllTabs];
  error = [MetricsAppInterface expectTotalCount:0
                                   forHistogram:@"NewTabPage.TimeSpent"];
  GREYAssertNil(error, error.description);
  [self releaseHistogramTester];

  // Open an NTP and navigate to another URL.
  [self setupHistogramTester];
  error = [MetricsAppInterface expectTotalCount:0
                                   forHistogram:@"NewTabPage.TimeSpent"];
  GREYAssertNil(error, error.description);
  [ChromeEarlGrey openNewTab];
  [ChromeEarlGrey loadURL:pageURL];
  [ChromeEarlGrey waitForWebStateContainingText:kPageLoadedString];

  error = [MetricsAppInterface expectTotalCount:1
                                   forHistogram:@"NewTabPage.TimeSpent"];
  GREYAssertNil(error, error.description);
  [self releaseHistogramTester];

  // Open an NTP and switch tab.
  [ChromeEarlGrey closeAllTabs];
  [ChromeEarlGrey openNewTab];
  [ChromeEarlGrey loadURL:pageURL];
  [ChromeEarlGrey waitForWebStateContainingText:kPageLoadedString];

  [self setupHistogramTester];
  error = [MetricsAppInterface expectTotalCount:0
                                   forHistogram:@"NewTabPage.TimeSpent"];
  GREYAssertNil(error, error.description);
  [ChromeEarlGrey openNewTab];
  [ChromeEarlGrey selectTabAtIndex:0];
  error = [MetricsAppInterface expectTotalCount:1
                                   forHistogram:@"NewTabPage.TimeSpent"];
  GREYAssertNil(error, error.description);
  [ChromeEarlGrey selectTabAtIndex:1];
  error = [MetricsAppInterface expectTotalCount:1
                                   forHistogram:@"NewTabPage.TimeSpent"];
  GREYAssertNil(error, error.description);
  [ChromeEarlGrey selectTabAtIndex:0];
  error = [MetricsAppInterface expectTotalCount:2
                                   forHistogram:@"NewTabPage.TimeSpent"];
  GREYAssertNil(error, error.description);
  [self releaseHistogramTester];
}

// Tests that all items are accessible on the incognito page.
- (void)testAccessibilityOnIncognitoTab {
  [ChromeEarlGrey openNewIncognitoTab];
  GREYAssert(WaitForHistoryToDisappear(), @"History did not disappear.");
  [ChromeEarlGrey verifyAccessibilityForCurrentScreen];
  [ChromeEarlGrey closeAllIncognitoTabs];
}

// Tests that the new tab opens the policy's New Tab Page Location when the URL
// is valid.
- (void)testValidNTPLocation {
  GREYAssertTrue(self.testServer->Start(), @"Test server failed to start.");
  const GURL expectedURL = self.testServer->GetURL(kPageURL);

  // Setup the policy's NTP Location URL.
  [self configureAppWithNTPLocation:expectedURL.spec().c_str()];

  // Open a new tab page.
  [ChromeEarlGrey openNewTab];

  // Wait until the page has finished loading.
  [ChromeEarlGrey waitForPageToFinishLoading];

  // Verify that the new tab URL is the correct one.
  const GURL currentURL = [ChromeEarlGrey webStateVisibleURL];
  GREYAssertEqual(expectedURL, currentURL, @"Page navigated unexpectedly to %s",
                  currentURL.spec().c_str());
}

// Tests that the new tab doesn't open the policy's New Tab Page Location when
// the URL is invalid.
- (void)testInvalidNTPLocation {
  // Setup the policy's NTP Location URL.
  [self configureAppWithNTPLocation:kInvalidNTPLocation];

  // Open a new tab page.
  [ChromeEarlGrey openNewTab];

  // Verify that the new tab URL is chrome://newtab/.
  const GURL expectedURL(kChromeUINewTabURL);
  const GURL currentURL = [ChromeEarlGrey webStateVisibleURL];
  GREYAssertEqual(expectedURL, currentURL, @"Page navigated unexpectedly to %s",
                  currentURL.spec().c_str());
}

@end
