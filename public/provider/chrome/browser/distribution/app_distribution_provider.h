// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_PUBLIC_PROVIDER_CHROME_BROWSER_DISTRIBUTION_APP_DISTRIBUTION_PROVIDER_H_
#define IOS_PUBLIC_PROVIDER_CHROME_BROWSER_DISTRIBUTION_APP_DISTRIBUTION_PROVIDER_H_

#include <string>

#include "base/memory/scoped_refptr.h"
#include "base/time/time.h"

namespace network {
class SharedURLLoaderFactory;
}  // namespace network

class AppDistributionProvider {
 public:
  AppDistributionProvider();
  virtual ~AppDistributionProvider();

  AppDistributionProvider(const AppDistributionProvider&) = delete;
  AppDistributionProvider& operator=(const AppDistributionProvider&) = delete;

  // Returns the distribution brand code.
  virtual std::string GetDistributionBrandCode();

  // Schedules distribution notifications to be sent using the given |context|.
  virtual void ScheduleDistributionNotifications(
      scoped_refptr<network::SharedURLLoaderFactory> shared_url_loader_factory,
      bool is_first_run);

  // Cancels any pending distribution notifications.
  virtual void CancelDistributionNotifications();

  // Initializes Firebase for installation attribution purpose. |install_date|
  // is used to detect "legacy" users that installed Chrome before Firebase
  // was integrated and thus should not have Firebase enabled.
  virtual void InitializeFirebase(base::Time install_date, bool is_first_run);
};

#endif  // IOS_PUBLIC_PROVIDER_CHROME_BROWSER_DISTRIBUTION_APP_DISTRIBUTION_PROVIDER_H_
