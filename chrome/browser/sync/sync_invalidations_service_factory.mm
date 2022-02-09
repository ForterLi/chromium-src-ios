// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/sync/sync_invalidations_service_factory.h"

#include "base/no_destructor.h"
#include "components/gcm_driver/gcm_profile_service.h"
#include "components/gcm_driver/instance_id/instance_id_profile_service.h"
#include "components/keyed_service/ios/browser_state_dependency_manager.h"
#include "components/sync/base/features.h"
#include "components/sync/invalidations/sync_invalidations_service_impl.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/gcm/instance_id/ios_chrome_instance_id_profile_service_factory.h"
#include "ios/chrome/browser/gcm/ios_chrome_gcm_profile_service_factory.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// static
syncer::SyncInvalidationsService*
SyncInvalidationsServiceFactory::GetForBrowserState(
    ChromeBrowserState* browser_state) {
  return static_cast<syncer::SyncInvalidationsService*>(
      GetInstance()->GetServiceForBrowserState(browser_state, /*create=*/true));
}

// static
SyncInvalidationsServiceFactory*
SyncInvalidationsServiceFactory::GetInstance() {
  static base::NoDestructor<SyncInvalidationsServiceFactory> instance;
  return instance.get();
}

SyncInvalidationsServiceFactory::SyncInvalidationsServiceFactory()
    : BrowserStateKeyedServiceFactory(
          "SyncInvalidationsService",
          BrowserStateDependencyManager::GetInstance()) {
  DependsOn(IOSChromeGCMProfileServiceFactory::GetInstance());
  DependsOn(IOSChromeInstanceIDProfileServiceFactory::GetInstance());
}

SyncInvalidationsServiceFactory::~SyncInvalidationsServiceFactory() = default;

std::unique_ptr<KeyedService>
SyncInvalidationsServiceFactory::BuildServiceInstanceFor(
    web::BrowserState* context) const {
  if (!base::FeatureList::IsEnabled(syncer::kSyncSendInterestedDataTypes)) {
    return nullptr;
  }

  ChromeBrowserState* browser_state =
      ChromeBrowserState::FromBrowserState(context);

  gcm::GCMDriver* gcm_driver =
      IOSChromeGCMProfileServiceFactory::GetForBrowserState(browser_state)
          ->driver();
  instance_id::InstanceIDDriver* instance_id_driver =
      IOSChromeInstanceIDProfileServiceFactory::GetForBrowserState(
          browser_state)
          ->driver();
  return std::make_unique<syncer::SyncInvalidationsServiceImpl>(
      gcm_driver, instance_id_driver);
}
