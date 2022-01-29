// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/main/scene_state_browser_agent.h"

#include "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/main/test_browser.h"
#import "ios/chrome/browser/ui/main/scene_state.h"
#include "ios/web/public/test/web_task_environment.h"
#include "testing/platform_test.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

class SceneStateBrowserAgentTest : public PlatformTest {
 public:
  SceneStateBrowserAgentTest() {
    browser_state_ = TestChromeBrowserState::Builder().Build();
    browser_ = std::make_unique<TestBrowser>(browser_state_.get());
    scene_state_ = [[SceneState alloc] initWithAppState:nil];
  }

 protected:
  web::WebTaskEnvironment task_environment_;
  std::unique_ptr<TestChromeBrowserState> browser_state_;
  std::unique_ptr<TestBrowser> browser_;
  SceneState* scene_state_;
};

TEST_F(SceneStateBrowserAgentTest, SetAndRetrieveSceneState) {
  SceneStateBrowserAgent::CreateForBrowser(browser_.get(), scene_state_);

  SceneStateBrowserAgent* agent =
      SceneStateBrowserAgent::FromBrowser(browser_.get());
  EXPECT_NE(nullptr, agent);

  EXPECT_EQ(scene_state_, agent->GetSceneState());
}

}  // anonymous namespace
