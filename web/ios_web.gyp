# Copyright 2014 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

{
  'variables': {
    'chromium_code': 1,
   },
  'targets': [
    {
      # GN version: //ios/web/public/app
      'target_name': 'ios_web_app',
      'type': 'static_library',
      'include_dirs': [
        '../..',
      ],
      'dependencies': [
        'ios_web',
        '../../base/base.gyp:base',
        '../../base/base.gyp:base_i18n',
        '../../crypto/crypto.gyp:crypto',
        '../../net/net.gyp:net',
        '../../ui/base/ui_base.gyp:ui_base',
        '../../ui/gfx/gfx.gyp:gfx',
        '../../ui/gfx/gfx.gyp:gfx_geometry',
      ],
      'sources': [
        'app/web_main.mm',
        'app/web_main_loop.h',
        'app/web_main_loop.mm',
        'app/web_main_runner.h',
        'app/web_main_runner.mm',
        'public/app/web_main.h',
        'public/app/web_main_delegate.h',
        'public/app/web_main_parts.h',
      ],
    },
    {
      # GN version: //ios/web
      'target_name': 'ios_web',
      'type': 'static_library',
      'include_dirs': [
        '../..',
      ],
      'dependencies': [
        'ios_web_core',
        'ios_web_resources.gyp:ios_web_resources',
        'js_resources',
        'user_agent',
        '../../base/base.gyp:base',
        '../../components/url_formatter/url_formatter.gyp:url_formatter',
        '../../ios/net/ios_net.gyp:ios_net',
        '../../ios/third_party/blink/blink_html_tokenizer.gyp:blink_html_tokenizer',
        '../../net/net.gyp:net',
        '../../mojo/mojo_edk.gyp:mojo_system_impl',
        '../../mojo/mojo_public.gyp:mojo_public',
        '../../services/shell/shell_public.gyp:shell_public',
        '../../ui/base/ui_base.gyp:ui_base',
        '../../ui/gfx/gfx.gyp:gfx',
        '../../ui/gfx/gfx.gyp:gfx_geometry',
        '../../ui/resources/ui_resources.gyp:ui_resources',
        '../../url/url.gyp:url_lib',
      ],
      'sources': [
        '<(SHARED_INTERMEDIATE_DIR)/ui/resources/grit/webui_resources_map.cc',
        'active_state_manager_impl.h',
        'active_state_manager_impl.mm',
        'alloc_with_zone_interceptor.h',
        'alloc_with_zone_interceptor.mm',
        'browser_state.mm',
        'browser_url_rewriter_impl.h',
        'browser_url_rewriter_impl.mm',
        'interstitials/html_web_interstitial_impl.h',
        'interstitials/html_web_interstitial_impl.mm',
        'interstitials/native_web_interstitial_impl.h',
        'interstitials/native_web_interstitial_impl.mm',
        'interstitials/web_interstitial_facade_delegate.h',
        'interstitials/web_interstitial_impl.h',
        'interstitials/web_interstitial_impl.mm',
        'load_committed_details.cc',
        'navigation/crw_session_certificate_policy_manager.h',
        'navigation/crw_session_certificate_policy_manager.mm',
        'navigation/crw_session_controller+private_constructors.h',
        'navigation/crw_session_controller.h',
        'navigation/crw_session_controller.mm',
        'navigation/crw_session_entry.h',
        'navigation/crw_session_entry.mm',
        'navigation/navigation_item_facade_delegate.h',
        'navigation/navigation_item_impl.h',
        'navigation/navigation_item_impl.mm',
        'navigation/navigation_manager_delegate.h',
        'navigation/navigation_manager_facade_delegate.h',
        'navigation/navigation_manager_impl.h',
        'navigation/navigation_manager_impl.mm',
        'navigation/nscoder_util.h',
        'navigation/nscoder_util.mm',
        'navigation/time_smoother.cc',
        'navigation/time_smoother.h',
        'net/cert_host_pair.cc',
        'net/cert_host_pair.h',
        'net/cert_policy.cc',
        'net/cert_store_impl.cc',
        'net/cert_store_impl.h',
        'net/cert_verifier_block_adapter.cc',
        'net/cert_verifier_block_adapter.h',
        'net/certificate_policy_cache.cc',
        'net/clients/crw_js_injection_network_client.h',
        'net/clients/crw_js_injection_network_client.mm',
        'net/clients/crw_js_injection_network_client_factory.h',
        'net/clients/crw_js_injection_network_client_factory.mm',
        'net/clients/crw_redirect_network_client.h',
        'net/clients/crw_redirect_network_client.mm',
        'net/clients/crw_redirect_network_client_factory.h',
        'net/clients/crw_redirect_network_client_factory.mm',
        'net/cookie_notification_bridge.h',
        'net/cookie_notification_bridge.mm',
        'net/crw_cert_verification_controller.h',
        'net/crw_cert_verification_controller.mm',
        'net/crw_request_tracker_delegate.h',
        'net/crw_ssl_status_updater.h',
        'net/crw_ssl_status_updater.mm',
        'net/request_group_util.h',
        'net/request_group_util.mm',
        'net/request_tracker_data_memoizing_store.h',
        'net/request_tracker_factory_impl.h',
        'net/request_tracker_factory_impl.mm',
        'net/request_tracker_impl.h',
        'net/request_tracker_impl.mm',
        'net/web_http_protocol_handler_delegate.h',
        'net/web_http_protocol_handler_delegate.mm',
        'public/active_state_manager.h',
        'public/block_types.h',
        'public/browser_state.h',
        'public/browser_url_rewriter.h',
        'public/cert_policy.h',
        'public/cert_store.h',
        'public/certificate_policy_cache.h',
        'public/favicon_status.cc',
        'public/favicon_status.h',
        'public/favicon_url.cc',
        'public/favicon_url.h',
        'public/interstitials/web_interstitial.h',
        'public/interstitials/web_interstitial_delegate.h',
        'public/load_committed_details.h',
        'public/navigation_item.h',
        'public/navigation_manager.h',
        'public/origin_util.h',
        'public/origin_util.mm',
        'public/referrer.h',
        'public/referrer_util.cc',
        'public/referrer_util.h',
        'public/security_style.h',
        'public/ssl_status.cc',
        'public/ssl_status.h',
        'public/string_util.h',
        'public/url_scheme_util.h',
        'public/url_schemes.h',
        'public/url_schemes.mm',
        'public/url_util.h',
        'public/user_metrics.h',
        'public/web/url_data_source_ios.h',
        'public/web_capabilities.cc',
        'public/web_capabilities.h',
        'public/web_client.h',
        'public/web_client.mm',
        'public/web_kit_constants.h',
        'public/web_state/context_menu_params.h',
        'public/web_state/credential.h',
        'public/web_state/crw_web_controller_observer.h',
        'public/web_state/crw_web_user_interface_delegate.h',
        'public/web_state/crw_web_view_proxy.h',
        'public/web_state/crw_web_view_scroll_view_proxy.h',
        'public/web_state/global_web_state_observer.h',
        'public/web_state/js/credential_util.h',
        'public/web_state/js/crw_js_injection_evaluator.h',
        'public/web_state/js/crw_js_injection_manager.h',
        'public/web_state/js/crw_js_injection_receiver.h',
        'public/web_state/page_display_state.h',
        'public/web_state/page_display_state.mm',
        'public/web_state/ui/crw_content_view.h',
        'public/web_state/ui/crw_generic_content_view.h',
        'public/web_state/ui/crw_native_content.h',
        'public/web_state/ui/crw_native_content_provider.h',
        'public/web_state/ui/crw_web_delegate.h',
        'public/web_state/ui/crw_web_view_content_view.h',
        'public/web_state/url_verification_constants.h',
        'public/web_state/web_state.h',
        'public/web_state/web_state_delegate.h',
        'public/web_state/web_state_delegate_bridge.h',
        'public/web_state/web_state_observer.h',
        'public/web_state/web_state_observer_bridge.h',
        'public/web_state/web_state_policy_decider.h',
        'public/web_state/web_state_user_data.h',
        'public/web_thread.h',
        'public/web_thread_delegate.h',
        'public/web_ui_ios_data_source.h',
        'public/web_view_creation_util.h',
        'string_util.cc',
        'url_scheme_util.mm',
        'url_util.cc',
        'user_metrics.cc',
        'web_kit_constants.cc',
        'web_state/blocked_popup_info.h',
        'web_state/blocked_popup_info.mm',
        'web_state/context_menu_params.mm',
        'web_state/credential.cc',
        'web_state/crw_pass_kit_downloader.h',
        'web_state/crw_pass_kit_downloader.mm',
        'web_state/crw_web_view_proxy_impl.h',
        'web_state/crw_web_view_proxy_impl.mm',
        'web_state/crw_web_view_scroll_view_proxy.mm',
        'web_state/error_translation_util.h',
        'web_state/error_translation_util.mm',
        'web_state/global_web_state_event_tracker.h',
        'web_state/global_web_state_event_tracker.mm',
        'web_state/global_web_state_observer.cc',
        'web_state/js/credential_util.mm',
        'web_state/js/crw_js_injection_manager.mm',
        'web_state/js/crw_js_injection_receiver.mm',
        'web_state/js/crw_js_invoke_parameter_queue.h',
        'web_state/js/crw_js_invoke_parameter_queue.mm',
        'web_state/js/crw_js_plugin_placeholder_manager.h',
        'web_state/js/crw_js_plugin_placeholder_manager.mm',
        'web_state/js/crw_js_post_request_loader.h',
        'web_state/js/crw_js_post_request_loader.mm',
        'web_state/js/crw_js_window_id_manager.h',
        'web_state/js/crw_js_window_id_manager.mm',
        'web_state/js/page_script_util.h',
        'web_state/js/page_script_util.mm',
        'web_state/page_viewport_state.h',
        'web_state/page_viewport_state.mm',
        'web_state/ui/crw_generic_content_view.mm',
        'web_state/ui/crw_swipe_recognizer_provider.h',
        'web_state/ui/crw_touch_tracking_recognizer.h',
        'web_state/ui/crw_touch_tracking_recognizer.mm',
        'web_state/ui/crw_web_controller.h',
        'web_state/ui/crw_web_controller.mm',
        'web_state/ui/crw_web_controller_container_view.h',
        'web_state/ui/crw_web_controller_container_view.mm',
        'web_state/ui/crw_web_view_content_view.mm',
        'web_state/ui/crw_wk_script_message_router.h',
        'web_state/ui/crw_wk_script_message_router.mm',
        'web_state/ui/web_view_js_utils.h',
        'web_state/ui/web_view_js_utils.mm',
        'web_state/ui/wk_back_forward_list_item_holder.h',
        'web_state/ui/wk_back_forward_list_item_holder.mm',
        'web_state/ui/wk_web_view_configuration_provider.h',
        'web_state/ui/wk_web_view_configuration_provider.mm',
        'web_state/web_controller_observer_bridge.h',
        'web_state/web_controller_observer_bridge.mm',
        'web_state/web_state.mm',
        'web_state/web_state_delegate.mm',
        'web_state/web_state_delegate_bridge.mm',
        'web_state/web_state_facade_delegate.h',
        'web_state/web_state_impl.h',
        'web_state/web_state_impl.mm',
        'web_state/web_state_observer.mm',
        'web_state/web_state_observer_bridge.mm',
        'web_state/web_state_policy_decider.mm',
        'web_state/web_state_weak_ptr_factory.h',
        'web_state/web_state_weak_ptr_factory.mm',
        'web_state/web_view_internal_creation_util.h',
        'web_state/web_view_internal_creation_util.mm',
        'web_state/wk_web_view_security_util.h',
        'web_state/wk_web_view_security_util.mm',
        'web_thread_impl.cc',
        'web_thread_impl.h',
        'web_view_creation_util.mm',
        'webui/crw_web_ui_manager.h',
        'webui/crw_web_ui_manager.mm',
        'webui/crw_web_ui_page_builder.h',
        'webui/crw_web_ui_page_builder.mm',
        'webui/mojo_facade.h',
        'webui/mojo_facade.mm',
        'webui/mojo_js_constants.cc',
        'webui/mojo_js_constants.h',
        'webui/shared_resources_data_source_ios.h',
        'webui/shared_resources_data_source_ios.mm',
        'webui/url_data_manager_ios.cc',
        'webui/url_data_manager_ios.h',
        'webui/url_data_manager_ios_backend.h',
        'webui/url_data_manager_ios_backend.mm',
        'webui/url_data_source_ios.mm',
        'webui/url_data_source_ios_impl.cc',
        'webui/url_data_source_ios_impl.h',
        'webui/url_fetcher_block_adapter.h',
        'webui/url_fetcher_block_adapter.mm',
        'webui/web_ui_ios_controller_factory_registry.cc',
        'webui/web_ui_ios_controller_factory_registry.h',
        'webui/web_ui_ios_data_source_impl.h',
        'webui/web_ui_ios_data_source_impl.mm',
        'webui/web_ui_ios_impl.h',
        'webui/web_ui_ios_impl.mm',
      ],
      'link_settings': {
        'libraries': [
          '$(SDKROOT)/System/Library/Frameworks/WebKit.framework',
        ],
      },
    },
    # Target shared by ios_web and CrNet.
    {
      # GN version: //ios/web:core
      'target_name': 'ios_web_core',
      'type': 'static_library',
      'dependencies': [
        '../../base/base.gyp:base',
      ],
      'include_dirs': [
        '../..',
      ],
      'sources': [
        'crw_network_activity_indicator_manager.h',
        'crw_network_activity_indicator_manager.mm',
        'history_state_util.h',
        'history_state_util.mm',
      ],
    },
    {
      # GN version: //ios/web:web_bundle
      'target_name': 'ios_web_js_bundle',
      'type': 'none',
      'variables': {
        'closure_entry_point': '__crWeb.webBundle',
        'js_bundle_files': [
          'web_state/js/resources/base.js',
          'web_state/js/resources/common.js',
          'web_state/js/resources/console.js',
          'web_state/js/resources/core.js',
          'web_state/js/resources/dialog_overrides.js',
          'web_state/js/resources/message.js',
          'web_state/js/resources/web_bundle.js',
        ],
      },
      'sources': [
        'web_state/js/resources/base.js',
        'web_state/js/resources/common.js',
        'web_state/js/resources/console.js',
        'web_state/js/resources/core.js',
        'web_state/js/resources/dialog_overrides.js',
        'web_state/js/resources/message.js',
        'web_state/js/resources/web_bundle.js',
      ],
      '!sources': [
        # Remove all js files except web_bundle. Those files should not be
        # copied with the rest of resources, as they just Closure dependencies
        # for web_bundle.js. Dependencies were added as sources, so they get
        # indexed by Xcode.
        'web_state/js/resources/base.js',
        'web_state/js/resources/common.js',
        'web_state/js/resources/console.js',
        'web_state/js/resources/core.js',
        'web_state/js/resources/dialog_overrides.js',
        'web_state/js/resources/message.js',
      ],
      'link_settings': {
        'mac_bundle_resources': [
          '<(SHARED_INTERMEDIATE_DIR)/web_bundle.js',
        ],
      },
      'includes': [
        'js_compile_bundle.gypi'
      ],
    },
    {
      # GN version: //ios/web:web_ui_bundle
      'target_name': 'ios_web_ui_js_bundle',
      'type': 'none',
      'variables': {
        'closure_entry_point': '__crWeb.webUIBundle',
        'js_bundle_files': [
          '../third_party/requirejs/require.js',
          'webui/resources/web_ui_base.js',
          'webui/resources/web_ui_bind.js',
          'webui/resources/web_ui_bundle.js',
          'webui/resources/web_ui_favicons.js',
          'webui/resources/web_ui_module_load_notifier.js',
          'webui/resources/web_ui_send.js',
        ],
      },
      'sources': [
          '../third_party/requirejs/require.js',
          'webui/resources/web_ui_base.js',
          'webui/resources/web_ui_bind.js',
          'webui/resources/web_ui_bundle.js',
          'webui/resources/web_ui_favicons.js',
          'webui/resources/web_ui_module_load_notifier.js',
          'webui/resources/web_ui_send.js',
      ],
      '!sources': [
        # Remove all js files except web_ui_bundle. Those files should not be
        # copied with the rest of resources, as they just Closure dependencies
        # for web_ui_bundle.js. Dependencies were added as sources, so they get
        # indexed by Xcode.
        '../third_party/requirejs/require.js',
        'webui/resources/web_ui_base.js',
        'webui/resources/web_ui_bind.js',
        'webui/resources/web_ui_favicons.js',
        'webui/resources/web_ui_module_load_notifier.js',
        'webui/resources/web_ui_send.js',
      ],
      'link_settings': {
        'mac_bundle_resources': [
          '<(SHARED_INTERMEDIATE_DIR)/web_ui_bundle.js',
        ],
      },
      'includes': [
        'js_compile_bundle.gypi'
      ],
    },
    {
      # GN version: //ios/web:js_resources
      'target_name': 'js_resources',
      'type': 'none',
      'dependencies': [
        'ios_web_js_bundle',
        'ios_web_ui_js_bundle',
      ],
      'sources': [
        'web_state/js/resources/post_request.js',
        'web_state/js/resources/plugin_placeholder.js',
        'web_state/js/resources/window_id.js',
      ],
      'link_settings': {
        'mac_bundle_resources': [
          '<(SHARED_INTERMEDIATE_DIR)/post_request.js',
          '<(SHARED_INTERMEDIATE_DIR)/plugin_placeholder.js',
          '<(SHARED_INTERMEDIATE_DIR)/window_id.js',
        ],
      },
      'includes': [
        'js_compile_checked.gypi'
      ],
    },
    {
      # GN version: //ios/web:earl_grey_test_support
      'target_name': 'ios_web_earl_grey_test_support',
      'type': 'static_library',
      'dependencies': [
        'ios_web_test_support',
        '<(DEPTH)/ios/third_party/earl_grey/earl_grey.gyp:EarlGrey',
      ],
      'sources': [
        'public/test/earl_grey/web_view_matchers.h',
        'public/test/earl_grey/web_view_matchers.mm',
        'public/test/web_view_interaction_test_util.h',
        'public/test/web_view_interaction_test_util.mm',
      ],
    },
    {
      # GN version: //ios/web:test_support
      'target_name': 'ios_web_test_support',
      'type': 'static_library',
      'dependencies': [
        '../../base/base.gyp:test_support_base',
        '../../ios/testing/ios_testing.gyp:ocmock_support',
        '../../ios/third_party/gcdwebserver/gcdwebserver.gyp:gcdwebserver',
        '../../net/net.gyp:net_test_support',
        '../../testing/gmock.gyp:gmock',
        '../../testing/gtest.gyp:gtest',
        '../../third_party/ocmock/ocmock.gyp:ocmock',
        '../../ui/base/ui_base.gyp:ui_base',
        'ios_web',
        'test_mojo_bindings',
      ],
      'include_dirs': [
        '../..',
      ],
      'sources': [
        'public/test/crw_test_js_injection_receiver.h',
        'public/test/crw_test_js_injection_receiver.mm',
        'public/test/http_server.h',
        'public/test/http_server.mm',
        'public/test/http_server_util.h',
        'public/test/http_server_util.mm',
        'public/test/js_test_util.h',
        'public/test/js_test_util.mm',
        'public/test/navigation_test_util.h',
        'public/test/navigation_test_util.mm',
        'public/test/response_providers/data_response_provider.h',
        'public/test/response_providers/data_response_provider.mm',
        'public/test/response_providers/file_based_response_provider.h',
        'public/test/response_providers/file_based_response_provider.mm',
        'public/test/response_providers/file_based_response_provider_impl.h',
        'public/test/response_providers/file_based_response_provider_impl.mm',
        'public/test/response_providers/html_response_provider.h',
        'public/test/response_providers/html_response_provider.mm',
        'public/test/response_providers/html_response_provider_impl.h',
        'public/test/response_providers/html_response_provider_impl.mm',
        'public/test/response_providers/response_provider.h',
        'public/test/response_providers/response_provider.mm',
        'public/test/response_providers/string_response_provider.h',
        'public/test/response_providers/string_response_provider.mm',
        'public/test/scoped_testing_web_client.h',
        'public/test/scoped_testing_web_client.mm',
        'public/test/test_browser_state.cc',
        'public/test/test_browser_state.h',
        'public/test/test_redirect_observer.h',
        'public/test/test_redirect_observer.mm',
        'public/test/test_web_client.h',
        'public/test/test_web_client.mm',
        'public/test/test_web_state.h',
        'public/test/test_web_state.mm',
        'public/test/test_web_thread.h',
        'public/test/test_web_thread_bundle.h',
        'public/test/test_web_view_content_view.h',
        'public/test/test_web_view_content_view.mm',
        'public/test/web_test.h',
        'public/test/web_test.mm',
        'public/test/web_test_suite.h',
        'public/test/web_test_with_web_state.h',
        'public/test/web_test_with_web_state.mm',
        'test/crw_fake_web_controller_observer.h',
        'test/crw_fake_web_controller_observer.mm',
        'test/test_url_constants.cc',
        'test/test_url_constants.h',
        'test/test_web_thread.cc',
        'test/test_web_thread_bundle.cc',
        'test/web_int_test.h',
        'test/web_int_test.mm',
        'test/web_test_with_web_controller.h',
        'test/web_test_with_web_controller.mm',
        'test/web_test_suite.h',
        'test/web_test_suite.mm',
        'test/wk_web_view_crash_utils.h',
        'test/wk_web_view_crash_utils.mm',
      ],
    },
    {
      # GN version: //ios/web/test:mojo_bindings
      'target_name': 'test_mojo_bindings_mojom',
      'type': 'none',
      'variables': {
        'mojom_files': [
          'test/mojo_test.mojom',
        ],
      },
      'include_dirs': [
        '..',
      ],
      'includes': [ '../../mojo/mojom_bindings_generator_explicit.gypi' ],
    },
    {
      # GN version: //ios/web/test:mojo_bindings
      'target_name': 'test_mojo_bindings',
      'type': 'static_library',
      'dependencies': [
        '../../mojo/mojo_base.gyp:mojo_common_lib',
        '../../mojo/mojo_public.gyp:mojo_cpp_bindings',
        'test_mojo_bindings_mojom',
      ],
      'include_dirs': [
        '..',
      ],
    },
    {
      # GN version: //ios/web:user_agent
      'target_name': 'user_agent',
      'type': 'static_library',
      'include_dirs': [
        '../..',
      ],
      'dependencies': [
        '../../base/base.gyp:base'
      ],
      'sources': [
        'public/user_agent.h',
        'public/user_agent.mm',
      ],
    },
  ],
}
