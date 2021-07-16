// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_POLICY_CHROME_BROWSER_CLOUD_MANAGEMENT_CONTROLLER_IOS_H_
#define IOS_CHROME_BROWSER_POLICY_CHROME_BROWSER_CLOUD_MANAGEMENT_CONTROLLER_IOS_H_

#include "components/enterprise/browser/controller/chrome_browser_cloud_management_controller.h"

namespace policy {

// iOS implementation of the platform-specific operations of CBCMController.
class ChromeBrowserCloudManagementControllerIOS
    : public ChromeBrowserCloudManagementController::Delegate {
 public:
  ChromeBrowserCloudManagementControllerIOS();
  ChromeBrowserCloudManagementControllerIOS(
      const ChromeBrowserCloudManagementControllerIOS&) = delete;
  ChromeBrowserCloudManagementControllerIOS& operator=(
      const ChromeBrowserCloudManagementControllerIOS&) = delete;

  ~ChromeBrowserCloudManagementControllerIOS() override;

  // ChromeBrowserCloudManagementController::Delegate implementation.
  void SetDMTokenStorageDelegate() override;
  int GetUserDataDirKey() override;
  base::FilePath GetExternalPolicyDir() override;
  NetworkConnectionTrackerGetter CreateNetworkConnectionTrackerGetter()
      override;
  void InitializeOAuthTokenFactory(
      scoped_refptr<network::SharedURLLoaderFactory> url_loader_factory,
      PrefService* local_state) override;
  void StartWatchingRegistration(
      ChromeBrowserCloudManagementController* controller) override;
  bool WaitUntilPolicyEnrollmentFinished() override;
  bool IsEnterpriseStartupDialogShowing() override;
  void OnServiceAccountSet(CloudPolicyClient* client,
                           const std::string& account_email) override;
  void ShutDown() override;
  MachineLevelUserCloudPolicyManager* GetMachineLevelUserCloudPolicyManager()
      override;
  DeviceManagementService* GetDeviceManagementService() override;
  scoped_refptr<network::SharedURLLoaderFactory> GetSharedURLLoaderFactory()
      override;
  scoped_refptr<base::SingleThreadTaskRunner> GetBestEffortTaskRunner()
      override;
  std::unique_ptr<enterprise_reporting::ReportingDelegateFactory>
  GetReportingDelegateFactory() override;
  void SetGaiaURLLoaderFactory(scoped_refptr<network::SharedURLLoaderFactory>
                                   url_loader_factory) override;
  bool ReadyToCreatePolicyManager() override;
  bool ReadyToInit() override;
};

}  // namespace policy

#endif  // IOS_CHROME_BROWSER_POLICY_CHROME_BROWSER_CLOUD_MANAGEMENT_CONTROLLER_IOS_H_
