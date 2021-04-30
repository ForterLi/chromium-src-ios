// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/overlays/public/infobar_banner/save_address_profile_infobar_banner_overlay_request_config.h"

#include "components/autofill/core/browser/autofill_save_update_address_profile_delegate_ios.h"
#include "components/infobars/core/infobar.h"
#include "ios/chrome/browser/infobars/infobar_ios.h"
#import "ios/chrome/browser/infobars/overlays/infobar_overlay_type.h"
#import "ios/chrome/browser/overlays/public/common/infobars/infobar_overlay_request_config.h"
#include "ios/chrome/grit/ios_strings.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace save_address_profile_infobar_overlays {

OVERLAY_USER_DATA_SETUP_IMPL(SaveAddressProfileBannerRequestConfig);

SaveAddressProfileBannerRequestConfig::SaveAddressProfileBannerRequestConfig(
    infobars::InfoBar* infobar)
    : infobar_(infobar) {
  DCHECK(infobar_);
  autofill::AutofillSaveUpdateAddressProfileDelegateIOS* delegate =
      autofill::AutofillSaveUpdateAddressProfileDelegateIOS::
          FromInfobarDelegate(infobar_->delegate());
  message_text_ = delegate->GetMessageText();
  button_label_text_ = delegate->GetMessageActionText();
  message_sub_text_ = delegate->GetMessageDescriptionText();
  is_update_banner_ = delegate->GetOriginalProfile() ? true : false;
}

SaveAddressProfileBannerRequestConfig::
    ~SaveAddressProfileBannerRequestConfig() = default;

void SaveAddressProfileBannerRequestConfig::CreateAuxiliaryData(
    base::SupportsUserData* user_data) {
  InfobarOverlayRequestConfig::CreateForUserData(
      user_data, static_cast<InfoBarIOS*>(infobar_),
      InfobarOverlayType::kBanner, false);
}

}  // namespace save_address_profile_infobar_overlays
