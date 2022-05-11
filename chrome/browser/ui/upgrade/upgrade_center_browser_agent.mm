// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/upgrade/upgrade_center_browser_agent.h"

#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/infobars/infobar_manager_impl.h"
#include "ios/chrome/browser/upgrade/upgrade_center.h"
#import "ios/chrome/browser/web_state_list/web_state_list.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

BROWSER_USER_DATA_KEY_IMPL(UpgradeCenterBrowserAgent)

UpgradeCenterBrowserAgent::UpgradeCenterBrowserAgent(Browser* browser) {
  DCHECK(browser);
  browser->AddObserver(this);
  browser->GetWebStateList()->AddObserver(this);
}

UpgradeCenterBrowserAgent::~UpgradeCenterBrowserAgent()

    void UpgradeCenterBrowserAgent::BrowserDestroyed(Browser* browser) {
  DCHECK(browser);
  browser->GetWebStateList()->RemoveObserver(this);
  browser->RemoveObserver(this);
}

void UpgradeCenterBrowserAgent::WebStateInsertedAt(WebStateList* web_state_list,
                                                   web::WebState* web_state,
                                                   int index,
                                                   bool activating) {
  DCHECK(web_state);

  // When adding new tabs, check what kind of reminder infobar should
  // be added to the new tab. Try to add only one of them.
  // This check is done when a new tab is added either through the Tools Menu
  // "New Tab", through a long press on the Tab Switcher button "New Tab", and
  // through creating a New Tab from the Tab Switcher. This logic needs to
  // happen after a new WebState has added and finished initial navigation. If
  // this happens earlier, the initial navigation may end up clearing the
  // infobar(s) that are just added.
  infobars::InfoBarManager* infoBarManager =
      InfoBarManagerImpl::FromWebState(web_state);
  NSString* tabID = web_state->GetStableIdentifier();

  // TODO(crbug.com/1324514): Replace [UpgradeCenter sharedInstance] with a
  // dependency
  [[UpgradeCenter sharedInstance] addInfoBarToManager:infoBarManager
                                             forTabId:tabID];
}

void UpgradeCenterBrowserAgent::WillDetachWebStateAt(
    WebStateList* web_state_list,
    web::WebState* web_state,
    int index) {
  DCHECK(web_state);

  // TODO(crbug.com/1324514): Replace [UpgradeCenter sharedInstance] with a
  // dependency
  [[UpgradeCenter sharedInstance]
      tabWillClose:web_state->GetStableIdentifier()];
}
