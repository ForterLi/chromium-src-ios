// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/web/sad_tab_tab_helper.h"

#include <memory>

#include "base/test/scoped_task_environment.h"
#include "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#include "ios/chrome/browser/chrome_url_constants.h"
#import "ios/chrome/browser/ntp/new_tab_page_tab_helper.h"
#import "ios/chrome/browser/ntp/new_tab_page_tab_helper_delegate.h"
#import "ios/chrome/browser/web/page_placeholder_tab_helper.h"
#import "ios/chrome/browser/web/sad_tab_tab_helper_delegate.h"
#import "ios/web/public/test/fakes/fake_navigation_context.h"
#import "ios/web/public/test/fakes/test_navigation_manager.h"
#import "ios/web/public/test/fakes/test_web_state.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// Delegate for testing.
@interface SadTabTabHelperTestDelegate : NSObject<SadTabTabHelperDelegate>
// |repeatedFailure| could be used by the delegate to display different types of
// SadTabs.
@property(nonatomic, assign) BOOL repeatedFailure;
// YES if SadTab is currently being shown.
@property(nonatomic, assign) BOOL showingSadTab;
@end

@implementation SadTabTabHelperTestDelegate
@synthesize repeatedFailure = _repeatedFailure;

- (void)sadTabTabHelper:(SadTabTabHelper*)tabHelper
    presentSadTabForWebState:(web::WebState*)webState
             repeatedFailure:(BOOL)repeatedFailure {
  self.repeatedFailure = repeatedFailure;
  self.showingSadTab = YES;
}

- (void)sadTabTabHelperDismissSadTab:(SadTabTabHelper*)tabHelper {
  self.showingSadTab = NO;
}

- (void)sadTabTabHelper:(SadTabTabHelper*)tabHelper
    didShowForRepeatedFailure:(BOOL)repeatedFailure {
  self.repeatedFailure = repeatedFailure;
  self.showingSadTab = YES;
}

- (void)sadTabTabHelperDidHide:(SadTabTabHelper*)tabHelper {
  self.showingSadTab = NO;
}

@end

class SadTabTabHelperTest : public PlatformTest {
 protected:
  SadTabTabHelperTest()
      : application_(OCMClassMock([UIApplication class])),
        sad_tab_delegate_([[SadTabTabHelperTestDelegate alloc] init]) {
    browser_state_ = TestChromeBrowserState::Builder().Build();

    SadTabTabHelper::CreateForWebState(&web_state_);
    tab_helper()->SetDelegate(sad_tab_delegate_);
    PagePlaceholderTabHelper::CreateForWebState(&web_state_);
    OCMStub([application_ sharedApplication]).andReturn(application_);

    // Setup navigation manager.
    std::unique_ptr<web::TestNavigationManager> navigation_manager =
        std::make_unique<web::TestNavigationManager>();
    navigation_manager->SetBrowserState(browser_state_.get());
    navigation_manager_ = navigation_manager.get();
    web_state_.SetNavigationManager(std::move(navigation_manager));
    web_state_.SetBrowserState(browser_state_.get());
  }

  SadTabTabHelper* tab_helper() {
    return SadTabTabHelper::FromWebState(&web_state_);
  }

  ~SadTabTabHelperTest() override { [application_ stopMocking]; }

  base::test::ScopedTaskEnvironment environment_;
  std::unique_ptr<ios::ChromeBrowserState> browser_state_;
  web::TestWebState web_state_;
  web::TestNavigationManager* navigation_manager_;
  id application_;
  SadTabTabHelperTestDelegate* sad_tab_delegate_;
};

// Tests that SadTab is not presented for not shown web states. Navigation
// item is reloaded once web state was shown, and displays the page placeholder
// during the load.
TEST_F(SadTabTabHelperTest, ReloadedWhenWebStateWasShown) {
  OCMStub([application_ applicationState]).andReturn(UIApplicationStateActive);
  web_state_.WasHidden();

  // Delegate and TabHelper should not present a SadTab.
  EXPECT_FALSE(tab_helper()->is_showing_sad_tab());
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);

  // Helper should get notified of render process failure,
  // but Sad Tab should not be presented, because web state was not shown.
  web_state_.OnRenderProcessGone();
  EXPECT_FALSE(tab_helper()->is_showing_sad_tab());
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);

  // Navigation item must be reloaded once web state is shown, while displaying
  // the page placeholder during the load.
  EXPECT_FALSE(navigation_manager_->LoadIfNecessaryWasCalled());
  web_state_.WasShown();
  EXPECT_TRUE(PagePlaceholderTabHelper::FromWebState(&web_state_)
                  ->displaying_placeholder());
  EXPECT_TRUE(navigation_manager_->LoadIfNecessaryWasCalled());
}

// Tests that SadTab is not presented if app is in background and navigation
// item is reloaded once the app became active.
TEST_F(SadTabTabHelperTest, AppInBackground) {
  OCMStub([application_ applicationState])
      .andReturn(UIApplicationStateBackground);
  web_state_.WasShown();

  // Delegate and TabHelper should not present a SadTab.
  EXPECT_FALSE(tab_helper()->is_showing_sad_tab());
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);

  // Helper should get notified of render process failure,
  // but Sad Tab should not be presented, because application is backgrounded.
  web_state_.OnRenderProcessGone();
  EXPECT_FALSE(tab_helper()->is_showing_sad_tab());
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);

  // Navigation item must be reloaded once the app became active.
  EXPECT_FALSE(navigation_manager_->LoadIfNecessaryWasCalled());
  [[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationDidBecomeActiveNotification
                    object:nil];
  EXPECT_TRUE(PagePlaceholderTabHelper::FromWebState(&web_state_)
                  ->will_add_placeholder_for_next_navigation());
  EXPECT_TRUE(navigation_manager_->LoadIfNecessaryWasCalled());
}

// Tests that SadTab is not presented if app is displaying the NTP.
TEST_F(SadTabTabHelperTest, AppOnNTP) {
  web_state_.WasShown();

  web_state_.SetVisibleURL(GURL(kChromeUINewTabURL));
  id delegate = OCMProtocolMock(@protocol(NewTabPageTabHelperDelegate));
  NewTabPageTabHelper::CreateForWebState(&web_state_, delegate);

  // Delegate and TabHelper should not present a SadTab.
  EXPECT_FALSE(tab_helper()->is_showing_sad_tab());
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);

  // Helper should get notified of render process failure,
  // but Sad Tab should not be presented, because application is on the NTP.
  web_state_.OnRenderProcessGone();
  EXPECT_FALSE(tab_helper()->is_showing_sad_tab());
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);
}

// Tests that SadTab is not presented if app is in inactive  and navigation
// item is reloaded once the app became active.
TEST_F(SadTabTabHelperTest, AppIsInactive) {
  OCMStub([application_ applicationState])
      .andReturn(UIApplicationStateInactive);
  web_state_.WasShown();

  // Delegate and TabHelper should not present a SadTab.
  EXPECT_FALSE(tab_helper()->is_showing_sad_tab());
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);

  // Helper should get notified of render process failure,
  // but Sad Tab should not be presented, because application is inactive.
  web_state_.OnRenderProcessGone();
  EXPECT_FALSE(tab_helper()->is_showing_sad_tab());
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);

  // Navigation item must be reloaded once the app became active.
  EXPECT_FALSE(navigation_manager_->LoadIfNecessaryWasCalled());
  [[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationDidBecomeActiveNotification
                    object:nil];
  EXPECT_TRUE(PagePlaceholderTabHelper::FromWebState(&web_state_)
                  ->will_add_placeholder_for_next_navigation());
  EXPECT_TRUE(navigation_manager_->LoadIfNecessaryWasCalled());
}

// Tests that SadTab is presented for shown web states.
TEST_F(SadTabTabHelperTest, Presented) {
  OCMStub([application_ applicationState]).andReturn(UIApplicationStateActive);

  web_state_.WasShown();

  // Delegate and TabHelper should not present a SadTab.
  EXPECT_FALSE(tab_helper()->is_showing_sad_tab());
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);

  // Helper should get notified of render process failure. And the delegate
  // and TabHelper should present a SadTab.
  web_state_.OnRenderProcessGone();
  EXPECT_TRUE(tab_helper()->is_showing_sad_tab());
  EXPECT_TRUE(sad_tab_delegate_.showingSadTab);
}

// Tests that SadTab is removed by the navigation.
TEST_F(SadTabTabHelperTest, SadTabClearedByNavigation) {
  OCMStub([application_ applicationState]).andReturn(UIApplicationStateActive);

  web_state_.WasShown();

  // Delegate should not present a SadTab.
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);

  // Helper should get notified of render process failure. And the delegate
  // and TabHelper should present a SadTab.
  web_state_.OnRenderProcessGone();
  EXPECT_TRUE(tab_helper()->is_showing_sad_tab());
  ASSERT_TRUE(sad_tab_delegate_.showingSadTab);

  // Novigation should clear the Sad Tab.
  web::FakeNavigationContext context;
  web_state_.OnNavigationStarted(&context);
  EXPECT_FALSE(tab_helper()->is_showing_sad_tab());
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);
}

// Tests that SadTab is presented after web state is shown and removed when web
// state is hidden.
TEST_F(SadTabTabHelperTest, HideAndShowPresented) {
  OCMStub([application_ applicationState]).andReturn(UIApplicationStateActive);

  web_state_.WasShown();

  // Delegate and TabHelper should not present a SadTab.
  EXPECT_FALSE(tab_helper()->is_showing_sad_tab());
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);

  // Helper should get notified of render process failure. And the delegate
  // should present a SadTab.
  web_state_.OnRenderProcessGone();
  EXPECT_TRUE(sad_tab_delegate_.showingSadTab);

  // Delegate does not show Sad Tab anymore, because WebState was hidden. But
  // TabHelper still shows the Sad Tab.
  web_state_.WasHidden();
  EXPECT_TRUE(tab_helper()->is_showing_sad_tab());
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);

  web_state_.WasShown();
  EXPECT_TRUE(sad_tab_delegate_.showingSadTab);
  EXPECT_FALSE(sad_tab_delegate_.repeatedFailure);
}

// Tests that SadTab is presented after web state is shown and removed when web
// state is hidden.
TEST_F(SadTabTabHelperTest, HideAndShowPresentedForRepeatedFailure) {
  OCMStub([application_ applicationState]).andReturn(UIApplicationStateActive);

  web_state_.WasShown();

  // Delegate and TabHelper should not present a SadTab.
  EXPECT_FALSE(tab_helper()->is_showing_sad_tab());
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);

  // Helper should get notified of render process failure. And the delegate
  // should present a SadTab.
  web_state_.OnRenderProcessGone();
  EXPECT_TRUE(tab_helper()->is_showing_sad_tab());
  EXPECT_TRUE(sad_tab_delegate_.showingSadTab);

  // Simulate repeated failure.
  web_state_.OnRenderProcessGone();
  ASSERT_TRUE(sad_tab_delegate_.repeatedFailure);

  // Delegate does not show Sad Tab anymore, because WebState was hidden. But
  // TabHelper still shows the Sad Tab.
  web_state_.WasHidden();
  EXPECT_TRUE(tab_helper()->is_showing_sad_tab());
  EXPECT_FALSE(sad_tab_delegate_.showingSadTab);

  web_state_.WasShown();
  EXPECT_TRUE(tab_helper()->is_showing_sad_tab());
  EXPECT_TRUE(sad_tab_delegate_.showingSadTab);
  EXPECT_TRUE(sad_tab_delegate_.repeatedFailure);
}

// Tests that repeated failures are communicated to the delegate correctly.
TEST_F(SadTabTabHelperTest, RepeatedFailuresShowCorrectUI) {
  OCMStub([application_ applicationState]).andReturn(UIApplicationStateActive);
  web_state_.WasShown();

  // Helper should get notified of render process failure.
  web_state_.OnRenderProcessGone();

  // SadTab should be displayed and repeatedFailure should be NO.
  EXPECT_TRUE(tab_helper()->is_showing_sad_tab());
  EXPECT_TRUE(sad_tab_delegate_.showingSadTab);
  EXPECT_FALSE(sad_tab_delegate_.repeatedFailure);

  // On a second render process crash, SadTab should be displayed and
  // repeatedFailure should be YES.
  web_state_.OnRenderProcessGone();
  EXPECT_TRUE(tab_helper()->is_showing_sad_tab());
  EXPECT_TRUE(sad_tab_delegate_.showingSadTab);
  EXPECT_TRUE(sad_tab_delegate_.repeatedFailure);

  // All subsequent crashes should have repeatedFailure as YES.
  web_state_.OnRenderProcessGone();
  EXPECT_TRUE(tab_helper()->is_showing_sad_tab());
  EXPECT_TRUE(sad_tab_delegate_.showingSadTab);
  EXPECT_TRUE(sad_tab_delegate_.repeatedFailure);
}

// Tests that repeated failures can time out, and reset repeatedFailure to NO.
TEST_F(SadTabTabHelperTest, FailureInterval) {
  OCMStub([application_ applicationState]).andReturn(UIApplicationStateActive);

  // N.B. The test fixture web_state_ is not used for this test as a custom
  // |repeat_failure_interval| is required.
  std::unique_ptr<ios::ChromeBrowserState> browser_state =
      TestChromeBrowserState::Builder().Build();
  web::TestWebState web_state;
  web_state.SetBrowserState(browser_state.get());
  SadTabTabHelper::CreateForWebState(&web_state, 0.0f);
  SadTabTabHelper::FromWebState(&web_state)->SetDelegate(sad_tab_delegate_);
  PagePlaceholderTabHelper::CreateForWebState(&web_state);
  web_state.WasShown();

  // Helper should get notified of render process failure.
  // SadTab should be shown.
  web_state.OnRenderProcessGone();

  // SadTab should be displayed and repeatedFailure should be NO.
  EXPECT_TRUE(sad_tab_delegate_.showingSadTab);
  EXPECT_FALSE(sad_tab_delegate_.repeatedFailure);

  // On a second render process crash, SadTab should be displayed and
  // repeatedFailure should still be NO due to the 0.0f interval timeout.
  web_state.OnRenderProcessGone();
  EXPECT_TRUE(sad_tab_delegate_.showingSadTab);
  EXPECT_FALSE(sad_tab_delegate_.repeatedFailure);
}
