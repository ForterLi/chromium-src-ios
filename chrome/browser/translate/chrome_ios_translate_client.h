// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_TRANSLATE_CHROME_IOS_TRANSLATE_CLIENT_H_
#define IOS_CHROME_BROWSER_TRANSLATE_CHROME_IOS_TRANSLATE_CLIENT_H_

#import <Foundation/Foundation.h>

#include <memory>
#include <string>

#include "components/translate/core/browser/translate_client.h"
#include "components/translate/core/browser/translate_step.h"
#include "components/translate/core/common/translate_errors.h"
#include "components/translate/ios/browser/ios_translate_driver.h"
#include "ios/web/public/web_state_observer.h"
#import "ios/web/public/web_state_user_data.h"

class PrefService;

namespace language {
class AcceptLanguagesService;
}

namespace translate {
class TranslatePrefs;
class TranslateManager;
}  // namespace translate

namespace web {
class WebState;
}  // namespace web

class ChromeIOSTranslateClient
    : public translate::TranslateClient,
      public web::WebStateObserver,
      public web::WebStateUserData<ChromeIOSTranslateClient> {
 public:
  ChromeIOSTranslateClient(const ChromeIOSTranslateClient&) = delete;
  ChromeIOSTranslateClient& operator=(const ChromeIOSTranslateClient&) = delete;

  ~ChromeIOSTranslateClient() override;

  // Creates a translation client tab helper and attaches it to |web_state|
  static void CreateForWebState(web::WebState* web_state);

  // Helper method to return a new TranslatePrefs instance.
  static std::unique_ptr<translate::TranslatePrefs> CreateTranslatePrefs(
      PrefService* prefs);

  // Gets the associated TranslateManager.
  translate::TranslateManager* GetTranslateManager();

  // TranslateClient implementation.
  translate::IOSTranslateDriver* GetTranslateDriver() override;
  PrefService* GetPrefs() override;
  std::unique_ptr<translate::TranslatePrefs> GetTranslatePrefs() override;
  language::AcceptLanguagesService* GetTranslateAcceptLanguages() override;
  int GetInfobarIconID() const override;
  std::unique_ptr<infobars::InfoBar> CreateInfoBar(
      std::unique_ptr<translate::TranslateInfoBarDelegate> delegate)
      const override;
  bool ShowTranslateUI(translate::TranslateStep step,
                       const std::string& source_language,
                       const std::string& target_language,
                       translate::TranslateErrors::Type error_type,
                       bool triggered_from_menu) override;
  bool IsTranslatableURL(const GURL& url) override;
  bool IsAutofillAssistantRunning() const override;

 private:
  ChromeIOSTranslateClient(web::WebState* web_state);
  friend class web::WebStateUserData<ChromeIOSTranslateClient>;

  // web::WebStateObserver implementation.
  void WebStateDestroyed(web::WebState* web_state) override;

  // The WebState this instance is observing. Will be null after
  // WebStateDestroyed has been called.
  web::WebState* web_state_ = nullptr;

  std::unique_ptr<translate::TranslateManager> translate_manager_;
  translate::IOSTranslateDriver translate_driver_;

  WEB_STATE_USER_DATA_KEY_DECL();
};

#endif  // IOS_CHROME_BROWSER_TRANSLATE_CHROME_IOS_TRANSLATE_CLIENT_H_
