// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/credential_provider_extension/ui/feature_flags.h"

#include "ios/chrome/common/app_group/app_group_constants.h"
#include "ios/chrome/common/app_group/app_group_field_trial_version.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

BOOL IsPasswordCreationEnabled() {
  NSDictionary* allFeatures = [app_group::GetGroupUserDefaults()
      objectForKey:app_group::kChromeExtensionFieldTrialPreference];
  NSDictionary* featureData = allFeatures[@"PasswordCreationEnabled"];
  if (!featureData || kPasswordCreationFeatureVersion !=
                          [featureData[kFieldTrialVersionKey] intValue]) {
    return NO;
  }
  return [featureData[kFieldTrialValueKey] boolValue];
}
