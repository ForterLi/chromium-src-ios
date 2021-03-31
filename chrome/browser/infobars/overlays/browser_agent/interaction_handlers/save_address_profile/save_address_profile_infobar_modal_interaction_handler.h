// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_INFOBARS_OVERLAYS_BROWSER_AGENT_INTERACTION_HANDLERS_SAVE_ADDRESS_PROFILE_SAVE_ADDRESS_PROFILE_INFOBAR_MODAL_INTERACTION_HANDLER_H_
#define IOS_CHROME_BROWSER_INFOBARS_OVERLAYS_BROWSER_AGENT_INTERACTION_HANDLERS_SAVE_ADDRESS_PROFILE_SAVE_ADDRESS_PROFILE_INFOBAR_MODAL_INTERACTION_HANDLER_H_

#import "ios/chrome/browser/infobars/overlays/browser_agent/interaction_handlers/common/infobar_modal_interaction_handler.h"

class InfoBarIOS;

namespace autofill {
class AutofillSaveAddressProfileDelegateIOS;
}

// Helper object that updates the model layer for interaction events with the
// SaveAddressProfile infobar modal UI.
class SaveAddressProfileInfobarModalInteractionHandler
    : public InfobarModalInteractionHandler {
 public:
  SaveAddressProfileInfobarModalInteractionHandler();
  ~SaveAddressProfileInfobarModalInteractionHandler() override;

  // InfobarModalInteractionHandler:
  void PerformMainAction(InfoBarIOS* infobar) override;
  void InfobarVisibilityChanged(InfoBarIOS* infobar, bool visible) override;

 private:
  // InfobarModalInteractionHandler:
  std::unique_ptr<InfobarModalOverlayRequestCallbackInstaller>
  CreateModalInstaller() override;

  // Returns the SaveAddressProfile delegate from |infobar|.
  autofill::AutofillSaveAddressProfileDelegateIOS* GetInfoBarDelegate(
      InfoBarIOS* infobar);
};

#endif  // IOS_CHROME_BROWSER_INFOBARS_OVERLAYS_BROWSER_AGENT_INTERACTION_HANDLERS_SAVE_ADDRESS_PROFILE_SAVE_ADDRESS_PROFILE_INFOBAR_MODAL_INTERACTION_HANDLER_H_
