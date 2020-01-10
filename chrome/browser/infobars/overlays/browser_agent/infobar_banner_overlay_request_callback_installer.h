// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_INFOBARS_OVERLAYS_BROWSER_AGENT_INFOBAR_BANNER_OVERLAY_REQUEST_CALLBACK_INSTALLER_H_
#define IOS_CHROME_BROWSER_INFOBARS_OVERLAYS_BROWSER_AGENT_INFOBAR_BANNER_OVERLAY_REQUEST_CALLBACK_INSTALLER_H_

#include "ios/chrome/browser/overlays/public/overlay_request_callback_installer.h"

class OverlayRequestSupport;
class InfobarBannerInteractionHandler;

// Installer for callbacks that are added to OverlayRequests for infobar
// banners.
class InfobarBannerOverlayRequestCallbackInstaller
    : public OverlayRequestCallbackInstaller {
 public:
  // Constructor for an instance that installs callbacks for OverlayRequests
  // supported by |request_support| that forward interaction events to
  // |interaction_handler|.
  explicit InfobarBannerOverlayRequestCallbackInstaller(
      const OverlayRequestSupport* request_support,
      InfobarBannerInteractionHandler* interaction_handler);
  ~InfobarBannerOverlayRequestCallbackInstaller() override;

 private:
  // Called as a dispatch callback for |request| when |response| is configured
  // with an InfobarBannerMainActionResponse.
  void MainActionButtonTapped(OverlayRequest* request,
                              OverlayResponse* response);
  // Called as a dispatch callback for |request| when |response| is configured
  // with an InfobarBannerShowModalResponse.
  void ShowModalButtonTapped(OverlayRequest* request,
                             OverlayResponse* response);
  // Called as a completion callback for |request|, where |response| is the
  // completion response.
  void BannerCompleted(OverlayRequest* request, OverlayResponse* response);

  // OverlayRequestCallbackInstaller:
  const OverlayRequestSupport* GetRequestSupport() const override;
  void InstallCallbacksInternal(OverlayRequest* request) override;

  // The request support for |interaction_handler_|.
  const OverlayRequestSupport* request_support_ = nullptr;
  // The handler for received responses.
  InfobarBannerInteractionHandler* interaction_handler_ = nullptr;

  base::WeakPtrFactory<InfobarBannerOverlayRequestCallbackInstaller>
      weak_factory_{this};
};

#endif  // IOS_CHROME_BROWSER_INFOBARS_OVERLAYS_BROWSER_AGENT_INFOBAR_BANNER_OVERLAY_REQUEST_CALLBACK_INSTALLER_H_
