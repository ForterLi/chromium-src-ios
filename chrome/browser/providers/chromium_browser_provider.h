// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_PROVIDERS_CHROMIUM_BROWSER_PROVIDER_H_
#define IOS_CHROME_BROWSER_PROVIDERS_CHROMIUM_BROWSER_PROVIDER_H_

#include "ios/public/provider/chrome/browser/chrome_browser_provider.h"

class ChromiumBrowserProvider : public ios::ChromeBrowserProvider {
 public:
  ChromiumBrowserProvider();
  ~ChromiumBrowserProvider() override;

  // ChromeBrowserProvider implementation
  UITextField* CreateStyledTextField() const override NS_RETURNS_RETAINED;
  VoiceSearchProvider* GetVoiceSearchProvider() const override;

  id<LogoVendor> CreateLogoVendor(Browser* browser, web::WebState* web_state)
      const override NS_RETURNS_RETAINED;
  UserFeedbackProvider* GetUserFeedbackProvider() const override;
  OverridesProvider* GetOverridesProvider() const override;
  DiscoverFeedProvider* GetDiscoverFeedProvider() const override;
  std::unique_ptr<ios::ChromeIdentityService> CreateChromeIdentityService()
      override;

 private:
  std::unique_ptr<UserFeedbackProvider> user_feedback_provider_;
  std::unique_ptr<VoiceSearchProvider> voice_search_provider_;
  std::unique_ptr<OverridesProvider> overrides_provider_;
  std::unique_ptr<DiscoverFeedProvider> discover_feed_provider_;
};

#endif  // IOS_CHROME_BROWSER_PROVIDERS_CHROMIUM_BROWSER_PROVIDER_H_
