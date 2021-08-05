// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/public/provider/chrome/browser/app_distribution/app_distribution_api.h"

namespace ios {
namespace provider {

std::string GetBrandCode() {
  // Test has no brand code.
  return std::string();
}

void ScheduleAppDistributionNotifications(
    const scoped_refptr<network::SharedURLLoaderFactory>& url_loader_factory,
    bool is_first_run) {
  // Nothing to do for tests.
}

void CancelAppDistributionNotifications() {
  // Nothing to do for tests.
}

void InitializeFirebase(base::Time install_date, bool is_first_run) {
  // Nothing to do for tests.
}

}  // namespace provider
}  // namespace ios
