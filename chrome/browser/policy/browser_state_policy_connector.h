// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_POLICY_BROWSER_STATE_POLICY_CONNECTOR_H_
#define IOS_CHROME_BROWSER_POLICY_BROWSER_STATE_POLICY_CONNECTOR_H_

#include <memory>
#include <vector>

class BrowserPolicyConnectorIOS;

namespace policy {
class ConfigurationPolicyProvider;
class PolicyService;
}  // namespace policy

// BrowserStatePolicyConnector creates and manages the per-BrowserState policy
// components and their integration with PrefService.
class BrowserStatePolicyConnector {
 public:
  BrowserStatePolicyConnector();
  ~BrowserStatePolicyConnector();
  BrowserStatePolicyConnector(const BrowserStatePolicyConnector&) = delete;
  BrowserStatePolicyConnector& operator=(const BrowserStatePolicyConnector&) =
      delete;

  // Initializes this connector.
  void Init(BrowserPolicyConnectorIOS* browser_policy_connector);

  // Shuts this connector down in preparation for destruction.
  void Shutdown();

  // Returns the PolicyService managed by this connector.  This is never
  // nullptr.
  policy::PolicyService* GetPolicyService() const {
    return policy_service_.get();
  }

 private:
  // |policy_providers_| contains a list of the policy providers available for
  // the PolicyService of this connector, in decreasing order of priority.
  //
  // Note: All the providers appended to this vector must eventually become
  // initialized for every policy domain, otherwise some subsystems will never
  // use the policies exposed by the PolicyService!
  // The default ConfigurationPolicyProvider::IsInitializationComplete()
  // result is true, so take care if a provider overrides that.
  std::vector<policy::ConfigurationPolicyProvider*> policy_providers_;

  std::unique_ptr<policy::PolicyService> policy_service_;
};

#endif  // IOS_CHROME_BROWSER_POLICY_BROWSER_STATE_POLICY_CONNECTOR_H_
