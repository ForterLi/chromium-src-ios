// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/policy/policy_watcher_browser_agent.h"

#import "base/test/ios/wait_util.h"
#include "build/build_config.h"
#import "components/pref_registry/pref_registry_syncable.h"
#import "components/prefs/pref_service.h"
#import "components/signin/public/base/signin_pref_names.h"
#import "components/sync_preferences/pref_service_mock_factory.h"
#import "components/sync_preferences/pref_service_syncable.h"
#import "ios/chrome/app/application_delegate/app_state.h"
#import "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#import "ios/chrome/browser/main/test_browser.h"
#include "ios/chrome/browser/policy/policy_watcher_browser_agent_observer_bridge.h"
#import "ios/chrome/browser/prefs/browser_prefs.h"
#include "ios/chrome/browser/signin/authentication_service_factory.h"
#import "ios/chrome/browser/signin/authentication_service_fake.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/commands/policy_signout_commands.h"
#import "ios/chrome/browser/ui/main/scene_state_browser_agent.h"
#import "ios/chrome/browser/ui/main/test/fake_scene_state.h"
#import "ios/public/provider/chrome/browser/signin/fake_chrome_identity.h"
#import "ios/web/public/test/web_task_environment.h"
#include "testing/platform_test.h"
#include "third_party/ocmock/OCMock/OCMock.h"
#include "third_party/ocmock/gtest_support.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using sync_preferences::PrefServiceMockFactory;
using sync_preferences::PrefServiceSyncable;
using user_prefs::PrefRegistrySyncable;
using web::WebTaskEnvironment;

class PolicyWatcherBrowserAgentTest : public PlatformTest {
 protected:
  void SetUp() override {
    PlatformTest::SetUp();
    TestChromeBrowserState::Builder builder;
    builder.SetPrefService(CreatePrefService());
    builder.AddTestingFactory(
        AuthenticationServiceFactory::GetInstance(),
        base::BindRepeating(
            &AuthenticationServiceFake::CreateAuthenticationService));
    chrome_browser_state_ = builder.Build();

    // Set the initial pref value.
    chrome_browser_state_->GetPrefs()->SetBoolean(prefs::kSigninAllowed, true);

    // Set up the test browser and attach the browser agents.
    browser_ = std::make_unique<TestBrowser>(chrome_browser_state_.get());

    // Browser Agent under test.
    PolicyWatcherBrowserAgent::CreateForBrowser(browser_.get());
    agent_ = PolicyWatcherBrowserAgent::FromBrowser(browser_.get());

    // SceneState Browser Agent.
    app_state_ = [[AppState alloc] initWithBrowserLauncher:nil
                                        startupInformation:nil
                                       applicationDelegate:nil];
    scene_state_ = [[FakeSceneState alloc] initWithAppState:app_state_];
    scene_state_.activationLevel = SceneActivationLevelForegroundActive;
    SceneStateBrowserAgent::CreateForBrowser(browser_.get(), scene_state_);
  }

  std::unique_ptr<PrefServiceSyncable> CreatePrefService() {
    PrefServiceMockFactory factory;
    scoped_refptr<PrefRegistrySyncable> registry(new PrefRegistrySyncable);
    std::unique_ptr<PrefServiceSyncable> prefs =
        factory.CreateSyncable(registry.get());
    RegisterBrowserStatePrefs(registry.get());
    return prefs;
  }

  // Sign in in the authentication service with a fake identity.
  void SignIn() {
    FakeChromeIdentity* identity =
        [FakeChromeIdentity identityWithEmail:@"email@mail.com"
                                       gaiaID:@"gaiaID"
                                         name:@"myName"];
    AuthenticationServiceFactory::GetForBrowserState(
        chrome_browser_state_.get())
        ->SignIn(identity);
  }

  web::WebTaskEnvironment task_environment_;
  std::unique_ptr<TestChromeBrowserState> chrome_browser_state_;
  PolicyWatcherBrowserAgent* agent_;
  std::unique_ptr<Browser> browser_;
  FakeSceneState* scene_state_;
  // Keep app_state_ alive as it is a weak property of the scene state.
  AppState* app_state_;
};

#pragma mark - Tests.

// Tests that the browser agent doesn't monitor the pref if Initialize hasn't
// been called.
TEST_F(PolicyWatcherBrowserAgentTest, NoObservationIfNoInitialize) {
  // Set the initial pref value.
  chrome_browser_state_->GetPrefs()->SetBoolean(prefs::kSigninAllowed, true);

  // Set up the test browser and attach the browser agent under test.
  std::unique_ptr<Browser> browser =
      std::make_unique<TestBrowser>(chrome_browser_state_.get());
  PolicyWatcherBrowserAgent::CreateForBrowser(browser.get());

  // Set up the mock observer handler as strict mock. Calling it will fail the
  // test.
  id mockObserver =
      OCMStrictProtocolMock(@protocol(PolicyWatcherBrowserAgentObserving));
  PolicyWatcherBrowserAgentObserverBridge bridge(mockObserver);
  agent_->AddObserver(&bridge);

  // Action: disable browser sign-in.
  chrome_browser_state_->GetPrefs()->SetBoolean(prefs::kSigninAllowed, false);

  agent_->RemoveObserver(&bridge);
}

// Tests that the browser agent monitors the kSigninAllowed pref and notifies
// its observers when it changes.
TEST_F(PolicyWatcherBrowserAgentTest, ObservesSigninAllowed) {
  // Set the initial pref value.
  chrome_browser_state_->GetPrefs()->SetBoolean(prefs::kSigninAllowed, true);
  // Set up the mock observer handler.
  id mockObserver =
      OCMStrictProtocolMock(@protocol(PolicyWatcherBrowserAgentObserving));
  PolicyWatcherBrowserAgentObserverBridge bridge(mockObserver);
  agent_->AddObserver(&bridge);
  id mockHandler = OCMProtocolMock(@protocol(PolicySignoutPromptCommands));
  agent_->Initialize(mockHandler);

  // Setup the expectation after the Initialize to make sure that the observers
  // are notified when the pref is updated and not during Initialize().
  OCMExpect(
      [mockObserver policyWatcherBrowserAgentNotifySignInDisabled:agent_]);

  // Action: disable browser sign-in.
  chrome_browser_state_->GetPrefs()->SetBoolean(prefs::kSigninAllowed, false);

  // Verify the forceSignOut command was dispatched by the browser agent.
  EXPECT_OCMOCK_VERIFY(mockObserver);

  agent_->RemoveObserver(&bridge);
}

// Tests that the pref change doesn't trigger a command if the user isn't signed
// in.
TEST_F(PolicyWatcherBrowserAgentTest, NoCommandIfNotSignedIn) {
  AuthenticationService* authentication_service =
      AuthenticationServiceFactory::GetForBrowserState(
          chrome_browser_state_.get());

  ASSERT_FALSE(authentication_service->IsAuthenticated());

  // Strict mock, will fail if a method is called.
  id mockHandler =
      OCMStrictProtocolMock(@protocol(PolicySignoutPromptCommands));
  agent_->Initialize(mockHandler);

  // Action: disable browser sign-in.
  chrome_browser_state_->GetPrefs()->SetBoolean(prefs::kSigninAllowed, false);
}

// Tests that the pref change triggers a command if the user is signed
// in.
TEST_F(PolicyWatcherBrowserAgentTest, CommandIfSignedIn) {
  AuthenticationService* authentication_service =
      AuthenticationServiceFactory::GetForBrowserState(
          chrome_browser_state_.get());

  SignIn();

  ASSERT_TRUE(authentication_service->IsAuthenticated());

  id mockHandler = OCMProtocolMock(@protocol(PolicySignoutPromptCommands));
  agent_->Initialize(mockHandler);

  OCMExpect([mockHandler showPolicySignoutPrompt]);

  // Action: disable browser sign-in.
  chrome_browser_state_->GetPrefs()->SetBoolean(prefs::kSigninAllowed, false);

  // Verify the forceSignOut command was dispatched by the browser agent.
  EXPECT_OCMOCK_VERIFY(mockHandler);
  EXPECT_FALSE(authentication_service->IsAuthenticated());
}

// Tests that the pref change doesn't trigger a command if the scene isn't
// active.
TEST_F(PolicyWatcherBrowserAgentTest, NoCommandIfNotActive) {
  AuthenticationService* authentication_service =
      AuthenticationServiceFactory::GetForBrowserState(
          chrome_browser_state_.get());

  scene_state_.activationLevel = SceneActivationLevelForegroundInactive;

  SignIn();

  ASSERT_TRUE(authentication_service->IsAuthenticated());

  // Strict mock, will fail if a method is called.
  id mockHandler =
      OCMStrictProtocolMock(@protocol(PolicySignoutPromptCommands));
  agent_->Initialize(mockHandler);

  // Action: disable browser sign-in.
  chrome_browser_state_->GetPrefs()->SetBoolean(prefs::kSigninAllowed, false);

  EXPECT_TRUE(scene_state_.appState.shouldShowPolicySignoutPrompt);
  EXPECT_FALSE(authentication_service->IsAuthenticated());
}

// Tests that the handler is called and the user signed out if the policy is
// updated while the app is not running.
TEST_F(PolicyWatcherBrowserAgentTest, SignOutIfPolicyChangedAtColdStart) {
  // Create another Agent from a new browser to simulate a behaviour of "the
  // pref changed in background.

  // Update the pref and Sign in.
  chrome_browser_state_->GetPrefs()->SetBoolean(prefs::kSigninAllowed, false);
  AuthenticationService* authentication_service =
      AuthenticationServiceFactory::GetForBrowserState(
          chrome_browser_state_.get());
  SignIn();

  // Set up the test browser and attach the browser agents.
  std::unique_ptr<Browser> browser =
      std::make_unique<TestBrowser>(chrome_browser_state_.get());

  // Browser Agent under test.
  PolicyWatcherBrowserAgent::CreateForBrowser(browser.get());
  PolicyWatcherBrowserAgent* agent =
      PolicyWatcherBrowserAgent::FromBrowser(browser.get());

  // SceneState Browser Agent.
  AppState* app_state = [[AppState alloc] initWithBrowserLauncher:nil
                                               startupInformation:nil
                                              applicationDelegate:nil];
  FakeSceneState* scene_state =
      [[FakeSceneState alloc] initWithAppState:app_state];
  scene_state.activationLevel = SceneActivationLevelForegroundActive;
  SceneStateBrowserAgent::CreateForBrowser(browser.get(), scene_state);

  // The SignOut will occur when the handler is set.
  ASSERT_TRUE(authentication_service->IsAuthenticated());

  id mockHandler = OCMProtocolMock(@protocol(PolicySignoutPromptCommands));
  OCMExpect([mockHandler showPolicySignoutPrompt]);
  agent->Initialize(mockHandler);

  EXPECT_OCMOCK_VERIFY(mockHandler);
  EXPECT_FALSE(authentication_service->IsAuthenticated());
}

// Tests that the command to show the UI isn't sent if the authentication
// service is still signing out the user.
TEST_F(PolicyWatcherBrowserAgentTest, UINotShownWhileSignOut) {
  chrome_browser_state_->GetPrefs()->SetBoolean(prefs::kSigninAllowed, false);

  AuthenticationService* authentication_service =
      static_cast<AuthenticationServiceFake*>(
          AuthenticationServiceFactory::GetForBrowserState(
              chrome_browser_state_.get()));

  FakeChromeIdentity* identity =
      [FakeChromeIdentity identityWithEmail:@"email@google.com"
                                     gaiaID:@"gaiaID"
                                       name:@"myName"];
  authentication_service->SignIn(identity);

  ASSERT_TRUE(authentication_service->IsAuthenticated());

  // Strict protocol: method calls will fail until the method is stubbed.
  id mockHandler =
      OCMStrictProtocolMock(@protocol(PolicySignoutPromptCommands));
  agent_->Initialize(mockHandler);

  ASSERT_TRUE(authentication_service->IsAuthenticated());
  // As the SignOut callback hasn't been called yet, this shouldn't trigger a UI
  // update.
  agent_->SignInUIDismissed();

  OCMExpect([mockHandler showPolicySignoutPrompt]);

  base::RunLoop().RunUntilIdle();
  ASSERT_FALSE(authentication_service->IsAuthenticated());

  // Once the SignOut callback is executed, the command should be sent.
  EXPECT_OCMOCK_VERIFY(mockHandler);
}

// Tests that the command to show the UI is sent when the Browser Agent is
// notified of the UI being dismissed.
TEST_F(PolicyWatcherBrowserAgentTest, CommandSentWhenUIIsDismissed) {
  chrome_browser_state_->GetPrefs()->SetBoolean(prefs::kSigninAllowed, false);
  SignIn();

  // Strict protocol: method calls will fail until the method is stubbed.
  id mockHandler =
      OCMStrictProtocolMock(@protocol(PolicySignoutPromptCommands));
  OCMExpect([mockHandler showPolicySignoutPrompt]);

  agent_->Initialize(mockHandler);

  EXPECT_OCMOCK_VERIFY(mockHandler);

  // Reset the expectation for the SignInUIDismissed call.
  OCMExpect([mockHandler showPolicySignoutPrompt]);

  agent_->SignInUIDismissed();

  EXPECT_OCMOCK_VERIFY(mockHandler);
}
