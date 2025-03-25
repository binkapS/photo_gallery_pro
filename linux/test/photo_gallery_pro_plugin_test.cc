#include <flutter_linux/flutter_linux.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>
#include <gio/gio.h>

#include "include/photo_gallery_pro/photo_gallery_pro_plugin.h"
#include "photo_gallery_pro_plugin_private.h"

#include <iostream>

// Create a mock messenger for testing
struct _MockMessenger {
  FlBinaryMessenger parent_instance;
};

G_DECLARE_FINAL_TYPE(MockMessenger, mock_messenger, MOCK, MESSENGER,
                     FlBinaryMessenger)
G_DEFINE_TYPE(MockMessenger, mock_messenger, fl_binary_messenger_get_type())

static void mock_messenger_class_init(MockMessengerClass* klass) {}
static void mock_messenger_init(MockMessenger* self) {}

// Test fixture
class PhotoGalleryProPluginTest : public ::testing::Test {
 protected:
  void SetUp() override {
    g_autoptr(FlPluginRegistrar) registrar =
        fl_plugin_registrar_new(mock_messenger_new(), nullptr);
    plugin_ = photo_gallery_pro_plugin_new(registrar);
  }

  void TearDown() override {
    if (plugin_) {
      g_object_unref(plugin_);
      plugin_ = nullptr;
    }
  }

  static MockMessenger* mock_messenger_new() {
    return MOCK_MESSENGER(g_object_new(mock_messenger_get_type(), nullptr));
  }

  PhotoGalleryProPlugin* plugin_ = nullptr;
};

// Tests
TEST_F(PhotoGalleryProPluginTest, GetPluginInstance) {
  EXPECT_NE(plugin_, nullptr);
}

TEST_F(PhotoGalleryProPluginTest, HasPermission) {
  g_autoptr(FlMethodCall) call =
      fl_method_call_new("hasPermission", nullptr);
  
  g_autoptr(GError) error = nullptr;
  g_autoptr(FlMethodResponse) response =
      photo_gallery_pro_plugin_handle_method_call(plugin_, call, &error);
  
  ASSERT_NE(response, nullptr);
  EXPECT_TRUE(FL_IS_METHOD_SUCCESS_RESPONSE(response));
  
  FlValue* result = fl_method_success_response_get_result(
      FL_METHOD_SUCCESS_RESPONSE(response));
  EXPECT_TRUE(fl_value_get_bool(result));
}

TEST_F(PhotoGalleryProPluginTest, GetAlbums) {
  g_autoptr(FlValue) args = fl_value_new_map();
  g_autoptr(FlValue) media_type_key = fl_value_new_string("mediaType");
  g_autoptr(FlValue) media_type_value = fl_value_new_string("image");
  fl_value_set(args, media_type_key, media_type_value);
  
  g_autoptr(FlMethodCall) call =
      fl_method_call_new("getAlbums", args);
  
  g_autoptr(GError) error = nullptr;
  g_autoptr(FlMethodResponse) response =
      photo_gallery_pro_plugin_handle_method_call(plugin_, call, &error);
  
  ASSERT_NE(response, nullptr);
  EXPECT_TRUE(FL_IS_METHOD_SUCCESS_RESPONSE(response));
  
  FlValue* result = fl_method_success_response_get_result(
      FL_METHOD_SUCCESS_RESPONSE(response));
  EXPECT_TRUE(fl_value_get_type(result) == FL_VALUE_TYPE_LIST);
}

namespace photo_gallery_pro {
namespace test {

TEST(PhotoGalleryProPlugin, GetPlatformVersion) {
  g_autoptr(FlMethodResponse) response = get_platform_version();
  ASSERT_NE(response, nullptr);
  ASSERT_TRUE(FL_IS_METHOD_SUCCESS_RESPONSE(response));
  FlValue* result = fl_method_success_response_get_result(
      FL_METHOD_SUCCESS_RESPONSE(response));
  ASSERT_EQ(fl_value_get_type(result), FL_VALUE_TYPE_STRING);
  // The full string varies, so just validate that it has the right format.
  EXPECT_THAT(fl_value_get_string(result), testing::StartsWith("Linux "));
}

}  // namespace test
}  // namespace photo_gallery_pro
