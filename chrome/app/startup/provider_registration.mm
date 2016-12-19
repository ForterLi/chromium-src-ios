// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/app/startup/provider_registration.h"

#include "ios/chrome/browser/web/web_controller_provider_factory_impl.h"
#include "ios/public/provider/chrome/browser/chrome_browser_provider.h"

@implementation ProviderRegistration

+ (void)registerProviders {
  std::unique_ptr<ios::ChromeBrowserProvider> provider =
      ios::CreateChromeBrowserProvider();

  // Leak the providers.
  ios::SetChromeBrowserProvider(provider.release());
  ios::SetWebControllerProviderFactory(new WebControllerProviderFactoryImpl());
}

@end
