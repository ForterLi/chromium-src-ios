// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_AUTHENTICATION_ENTERPRISE_ENTERPRISE_UTILS_H_
#define IOS_CHROME_BROWSER_UI_AUTHENTICATION_ENTERPRISE_ENTERPRISE_UTILS_H_

#import <UIKit/UIKit.h>

#include "ios/chrome/browser/sync/sync_setup_service.h"

class PrefService;
namespace syncer {
class SyncService;
}

// List of Enterprise restriction options.
typedef NS_OPTIONS(NSUInteger, EnterpriseSignInRestrictions) {
  kNoEnterpriseRestriction = 0,
  kEnterpriseForceSignIn = 1 << 0,
  kEnterpriseRestrictAccounts = 1 << 1,
  kEnterpriseSyncTypesListDisabled = 1 << 2,
};

// Returns YES if some account restrictions are set.
bool IsRestrictAccountsToPatternsEnabled();

// Returns true if force signIn is set.
// DEPRECATED. Needs to use AuthenticationService::GetServiceStatus().
// TODO(crbug.com/1242320): Need to remove this method.
bool IsForceSignInEnabled();

// Returns true if the |dataType| is managed by policies (i.e. is not syncable).
bool IsManagedSyncDataType(PrefService* pref_service,
                           SyncSetupService::SyncableDatatype dataType);

// Returns true if any data type is managed by policies (i.e. is not syncable).
bool HasManagedSyncDataType(PrefService* pref_service);

// Returns current EnterpriseSignInRestrictions.
EnterpriseSignInRestrictions GetEnterpriseSignInRestrictions(
    PrefService* pref_service);

// true if sync is disabled.
bool IsSyncDisabledByPolicy(syncer::SyncService* sync_service);

#endif  // IOS_CHROME_BROWSER_UI_AUTHENTICATION_ENTERPRISE_ENTERPRISE_UTILS_H_
