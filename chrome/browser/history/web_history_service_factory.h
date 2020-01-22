// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_HISTORY_WEB_HISTORY_SERVICE_FACTORY_H_
#define IOS_CHROME_BROWSER_HISTORY_WEB_HISTORY_SERVICE_FACTORY_H_

#include <memory>

#include "base/macros.h"
#include "base/no_destructor.h"
#include "components/keyed_service/ios/browser_state_keyed_service_factory.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state_forward.h"

namespace history {
class WebHistoryService;
}

namespace ios {
// Singleton that owns all WebHistoryServices and associates them with
// ios::ChromeBrowserState.
class WebHistoryServiceFactory : public BrowserStateKeyedServiceFactory {
 public:
  static history::WebHistoryService* GetForBrowserState(
      ios::ChromeBrowserState* browser_state);
  static WebHistoryServiceFactory* GetInstance();

 private:
  friend class base::NoDestructor<WebHistoryServiceFactory>;

  WebHistoryServiceFactory();
  ~WebHistoryServiceFactory() override;

  // BrowserStateKeyedServiceFactory implementation.
  std::unique_ptr<KeyedService> BuildServiceInstanceFor(
      web::BrowserState* context) const override;

  DISALLOW_COPY_AND_ASSIGN(WebHistoryServiceFactory);
};

}  // namespace ios

#endif  // IOS_CHROME_BROWSER_HISTORY_WEB_HISTORY_SERVICE_FACTORY_H_
