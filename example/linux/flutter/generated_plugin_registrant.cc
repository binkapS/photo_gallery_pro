//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <photo_gallery_pro/photo_gallery_pro_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) photo_gallery_pro_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "PhotoGalleryProPlugin");
  photo_gallery_pro_plugin_register_with_registrar(photo_gallery_pro_registrar);
}
