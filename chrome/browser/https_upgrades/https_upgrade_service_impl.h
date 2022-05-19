// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_HTTPS_UPGRADES_HTTPS_UPGRADE_SERVICE_IMPL_H_
#define IOS_CHROME_BROWSER_HTTPS_UPGRADES_HTTPS_UPGRADE_SERVICE_IMPL_H_

#include <memory>
#include <set>
#include <string>

#include "components/keyed_service/core/keyed_service.h"
#include "components/security_interstitials/core/https_only_mode_allowlist.h"
#include "ios/components/security_interstitials/https_only_mode/https_upgrade_service.h"

class ChromeBrowserState;

// HttpsUpgradeServiceImpl tracks the allowlist decisions for HTTPS-Only mode.
// Decisions are scoped to the host.
class HttpsUpgradeServiceImpl : public HttpsUpgradeService {
 public:
  HttpsUpgradeServiceImpl(ChromeBrowserState* context);
  ~HttpsUpgradeServiceImpl() override;

  // Returns whether |host| can be loaded over http://.
  bool IsHttpAllowedForHost(const std::string& host) const override;

  // Allows future navigations to |host| over http://.
  void AllowHttpForHost(const std::string& host) override;

  void ClearAllowlist() override;

 private:
  std::unique_ptr<base::Clock> clock_;
  ChromeBrowserState* context_;
  security_interstitials::HttpsOnlyModeAllowlist allowlist_;
};

#endif  // IOS_CHROME_BROWSER_HTTPS_UPGRADES_HTTPS_UPGRADE_SERVICE_IMPL_H_
