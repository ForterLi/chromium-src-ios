// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_DOWNLOAD_BACKGROUND_SERVICE_BACKGROUND_DOWNLOAD_SERVICE_FACTORY_H_
#define IOS_CHROME_BROWSER_DOWNLOAD_BACKGROUND_SERVICE_BACKGROUND_DOWNLOAD_SERVICE_FACTORY_H_

#include <memory>

#include "base/no_destructor.h"
#include "components/keyed_service/ios/browser_state_keyed_service_factory.h"

class ChromeBrowserState;

namespace download {
class BackgroundDownloadService;
}

// Singleton that owns all BackgroundDownloadServiceFactory and associates them
// with ChromeBrowserState.
class BackgroundDownloadServiceFactory
    : public BrowserStateKeyedServiceFactory {
 public:
  static download::BackgroundDownloadService* GetForBrowserState(
      ChromeBrowserState* browser_state);
  static BackgroundDownloadServiceFactory* GetInstance();

 private:
  friend class base::NoDestructor<BackgroundDownloadServiceFactory>;

  BackgroundDownloadServiceFactory();
  ~BackgroundDownloadServiceFactory() override;
  BackgroundDownloadServiceFactory(const BackgroundDownloadServiceFactory&) =
      delete;
  BackgroundDownloadServiceFactory& operator=(
      const BackgroundDownloadServiceFactory&) = delete;

  // BrowserStateKeyedServiceFactory implementation.
  std::unique_ptr<KeyedService> BuildServiceInstanceFor(
      web::BrowserState* context) const override;
};

#endif  // IOS_CHROME_BROWSER_DOWNLOAD_BACKGROUND_SERVICE_BACKGROUND_DOWNLOAD_SERVICE_FACTORY_H_