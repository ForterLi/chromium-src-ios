// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/infobars/overlays/browser_agent/interaction_handlers/confirm/confirm_infobar_banner_interaction_handler.h"

#include "base/notreached.h"
#include "components/infobars/core/confirm_infobar_delegate.h"
#include "ios/chrome/browser/infobars/infobar_ios.h"
#import "ios/chrome/browser/overlays/public/infobar_banner/confirm_infobar_banner_overlay_request_config.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using confirm_infobar_overlays::ConfirmBannerRequestConfig;

#pragma mark - InfobarBannerInteractionHandler

ConfirmInfobarBannerInteractionHandler::ConfirmInfobarBannerInteractionHandler()
    : InfobarBannerInteractionHandler(
          ConfirmBannerRequestConfig::RequestSupport()) {}

ConfirmInfobarBannerInteractionHandler::
    ~ConfirmInfobarBannerInteractionHandler() = default;

void ConfirmInfobarBannerInteractionHandler::MainButtonTapped(
    InfoBarIOS* infobar) {
  infobar->set_accepted(GetInfobarDelegate(infobar)->Accept());
}

#pragma mark - Private

ConfirmInfoBarDelegate*
ConfirmInfobarBannerInteractionHandler::GetInfobarDelegate(
    InfoBarIOS* infobar) {
  ConfirmInfoBarDelegate* delegate =
      infobar->delegate()->AsConfirmInfoBarDelegate();
  DCHECK(delegate);
  return delegate;
}
