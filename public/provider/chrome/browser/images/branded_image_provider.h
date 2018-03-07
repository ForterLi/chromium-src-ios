// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_PUBLIC_PROVIDER_CHROME_BROWSER_IMAGES_BRANDED_IMAGE_PROVIDER_H_
#define IOS_PUBLIC_PROVIDER_CHROME_BROWSER_IMAGES_BRANDED_IMAGE_PROVIDER_H_

#include "base/macros.h"
#include "ios/public/provider/chrome/browser/images/branded_image_icon_types.h"

@class UIImage;

// BrandedImageProvider vends images that contain embedder-specific branding.
// When adding method to this class, do not forget to add Chromium specific
// implementation to ChromiumBrandedImageProvider (the file may not be in the
// Xcode project if you are using internal sources).
class BrandedImageProvider {
 public:
  BrandedImageProvider();
  virtual ~BrandedImageProvider();

  // Returns the 24pt x 24pt image to use for the "activity controls" item on
  // the accounts list screen.
  virtual UIImage* GetAccountsListActivityControlsImage();

  // Returns the 24pt x 24pt image to use for the "account and activity" item on
  // the clear browsing data settings screen.
  virtual UIImage* GetClearBrowsingDataAccountActivityImage();

  // Returns the 24pt x 24pt image to use for the "account and activity" item on
  // the clear browsing data settings screen.
  virtual UIImage* GetClearBrowsingDataSiteDataImage();

  // Returns the 16pt x 16pt image to use for the "sync settings" item on the
  // signin confirmation screen.
  virtual UIImage* GetSigninConfirmationSyncSettingsImage();

  // Returns the 16pt x 16pt image to use for the "personalize services" item on
  // the signin confirmation screen.
  virtual UIImage* GetSigninConfirmationPersonalizeServicesImage();

  // Sets |image_id| to contain the resource id corresponding to the 24pt x 24pt
  // image for the toolbar voice search button.  If this method returns false,
  // |image_id| is invalid and callers should fall back to a default image.  The
  // returned image should be used for all toolbar styles and all button states.
  virtual bool GetToolbarVoiceSearchButtonImageId(int* image_id);

  // Returns the 24pt x 24pt image corresponding to the given icon |type|.
  virtual UIImage* GetWhatsNewIconImage(WhatsNewIcon type);

  // Returns the 38pt x 38pt image to use for the "search the web" button.
  // Deprecated, instead use GetToolbarSearchButtonImage(SEARCH_ENGINE_GOOGLE).
  virtual UIImage* GetToolbarSearchButtonImage();

  // Returns the 38pt x 38pt image to use for the "search the web" button
  // corresponding to the |type| search engine.
  virtual UIImage* GetToolbarSearchButtonImage(SearchEngineIcon type);

  // Returns the 24pt x 24pt image to use for the "Download Google Drive" icon
  // on Download Manager UI.
  virtual UIImage* GetDownloadGoogleDriveImage();

 private:
  DISALLOW_COPY_AND_ASSIGN(BrandedImageProvider);
};

#endif  // IOS_PUBLIC_PROVIDER_CHROME_BROWSER_IMAGES_BRANDED_IMAGE_PROVIDER_H_
