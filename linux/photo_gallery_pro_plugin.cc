#include "include/photo_gallery_pro/photo_gallery_pro_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>
#include <gio/gio.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <string.h>
#include <sys/stat.h>
#include <dirent.h>

#define PHOTO_GALLERY_PRO_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), photo_gallery_pro_plugin_get_type(), \
                             PhotoGalleryProPlugin))

// Plugin class structure
struct _PhotoGalleryProPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(PhotoGalleryProPlugin, photo_gallery_pro_plugin, g_object_get_type())

// Forward declarations of helper functions
static int get_media_count(const gchar* dir_path, const gchar* media_type);
static void process_directory(const gchar* dir_path, const gchar* media_type, FlValue* albums);
static gchar* get_first_media_in_album(const gchar* album_id, const gchar* media_type);
static GdkPixbuf* generate_thumbnail(const gchar* file_path, int width, int height, GError** error);
static FlMethodResponse* get_album_thumbnail(FlMethodCall* method_call);
static FlMethodResponse* get_thumbnail(FlMethodCall* method_call);

// Helper function to count media files in a directory
static int get_media_count(const gchar* dir_path, const gchar* media_type) {
    DIR* dir = opendir(dir_path);
    if (!dir) return 0;

    int count = 0;
    struct dirent* entry;
    
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_type == DT_REG) {  // Regular file
            gchar* file_path = g_build_filename(dir_path, entry->d_name, NULL);
            
            // Check file extension
            const gchar* extension = strrchr(entry->d_name, '.');
            if (extension) {
                extension++; // Skip the dot
                if (g_strcmp0(media_type, "image") == 0) {
                    if (g_ascii_strcasecmp(extension, "jpg") == 0 ||
                        g_ascii_strcasecmp(extension, "jpeg") == 0 ||
                        g_ascii_strcasecmp(extension, "png") == 0) {
                        count++;
                    }
                } else if (g_strcmp0(media_type, "video") == 0) {
                    if (g_ascii_strcasecmp(extension, "mp4") == 0 ||
                        g_ascii_strcasecmp(extension, "avi") == 0 ||
                        g_ascii_strcasecmp(extension, "mkv") == 0) {
                        count++;
                    }
                }
            }
            g_free(file_path);
        }
    }
    
    closedir(dir);
    return count;
}

// Process directory to find albums
static void process_directory(const gchar* dir_path, const gchar* media_type, FlValue* albums) {
    DIR* dir = opendir(dir_path);
    if (!dir) return;

    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        // Skip . and ..
        if (g_strcmp0(entry->d_name, ".") == 0 || 
            g_strcmp0(entry->d_name, "..") == 0) {
            continue;
        }

        if (entry->d_type == DT_DIR) {
            gchar* full_path = g_build_filename(dir_path, entry->d_name, NULL);
            int count = get_media_count(full_path, media_type);
            
            if (count > 0) {
                // Create album object
                g_autoptr(FlValue) album = fl_value_new_map();
                
                // Set album properties
                fl_value_set(album, fl_value_new_string("id"), 
                            fl_value_new_string(entry->d_name));
                fl_value_set(album, fl_value_new_string("name"), 
                            fl_value_new_string(entry->d_name));
                fl_value_set(album, fl_value_new_string("type"), 
                            fl_value_new_string(media_type));
                fl_value_set(album, fl_value_new_string("count"), 
                            fl_value_new_int(count));
                
                // Add to albums list
                fl_value_append(albums, album);
            }
            
            g_free(full_path);
        }
    }
    
    closedir(dir);
}

// Find first media file in an album
static gchar* get_first_media_in_album(const gchar* album_id, const gchar* media_type) {
    const gchar* base_dir = g_get_user_special_dir(G_USER_DIRECTORY_PICTURES);
    if (!base_dir) return NULL;

    gchar* album_path = g_build_filename(base_dir, album_id, NULL);
    DIR* dir = opendir(album_path);
    if (!dir) {
        g_free(album_path);
        return NULL;
    }

    gchar* result = NULL;
    struct dirent* entry;
    
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_type == DT_REG) {
            const gchar* extension = strrchr(entry->d_name, '.');
            if (extension) {
                extension++; // Skip the dot
                if (g_strcmp0(media_type, "image") == 0) {
                    if (g_ascii_strcasecmp(extension, "jpg") == 0 ||
                        g_ascii_strcasecmp(extension, "jpeg") == 0 ||
                        g_ascii_strcasecmp(extension, "png") == 0) {
                        result = g_build_filename(album_path, entry->d_name, NULL);
                        break;
                    }
                } else if (g_strcmp0(media_type, "video") == 0) {
                    if (g_ascii_strcasecmp(extension, "mp4") == 0 ||
                        g_ascii_strcasecmp(extension, "avi") == 0 ||
                        g_ascii_strcasecmp(extension, "mkv") == 0) {
                        result = g_build_filename(album_path, entry->d_name, NULL);
                        break;
                    }
                }
            }
        }
    }
    
    closedir(dir);
    g_free(album_path);
    return result;
}

// Helper function to generate thumbnails
static GdkPixbuf* generate_thumbnail(const gchar* file_path, int width, int height, GError** error) {
    GdkPixbuf* pixbuf = gdk_pixbuf_new_from_file(file_path, error);
    if (!pixbuf) {
        return NULL;
    }

    // Calculate aspect ratio
    int orig_width = gdk_pixbuf_get_width(pixbuf);
    int orig_height = gdk_pixbuf_get_height(pixbuf);
    double scale = MIN((double)width / orig_width, (double)height / orig_height);

    int new_width = (int)(orig_width * scale);
    int new_height = (int)(orig_height * scale);

    // Create scaled thumbnail
    GdkPixbuf* thumbnail = gdk_pixbuf_scale_simple(pixbuf,
                                                  new_width,
                                                  new_height,
                                                  GDK_INTERP_BILINEAR);
    g_object_unref(pixbuf);
    
    return thumbnail;
}

// Method to get album thumbnail
static FlMethodResponse* get_album_thumbnail(FlMethodCall* method_call) {
    FlValue* args = fl_method_call_get_args(method_call);
    const gchar* album_id = fl_value_get_string(fl_value_lookup_string(args, "albumId"));
    const gchar* media_type = fl_value_get_string(fl_value_lookup_string(args, "mediaType"));
    
    // Find first media file in album
    gchar* media_path = get_first_media_in_album(album_id, media_type);
    if (!media_path) {
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
            "THUMBNAIL_ERROR",
            "No media found in album",
            nullptr));
    }

    // Generate thumbnail
    GError* error = NULL;
    GdkPixbuf* thumbnail = generate_thumbnail(media_path, 200, 200, &error);
    g_free(media_path);

    if (error != NULL) {
        g_autoptr(FlValue) error_details = fl_value_new_map();
        fl_value_set(error_details, 
                    fl_value_new_string("message"),
                    fl_value_new_string(error->message));
        g_error_free(error);
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
            "THUMBNAIL_ERROR",
            "Failed to generate thumbnail",
            error_details));
    }

    // Convert to bytes
    gchar* buffer;
    gsize buffer_size;
    gdk_pixbuf_save_to_buffer(thumbnail, &buffer, &buffer_size, "png", &error, NULL);
    g_object_unref(thumbnail);

    if (error != NULL) {
        g_autoptr(FlValue) error_details = fl_value_new_map();
        fl_value_set(error_details,
                    fl_value_new_string("message"),
                    fl_value_new_string(error->message));
        g_error_free(error);
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
            "THUMBNAIL_ERROR",
            "Failed to convert thumbnail",
            error_details));
    }

    // Create response
    g_autoptr(FlValue) result = fl_value_new_uint8_list((const uint8_t*)buffer, buffer_size);
    g_free(buffer);

    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Method to get media thumbnail
static FlMethodResponse* get_thumbnail(FlMethodCall* method_call) {
    FlValue* args = fl_method_call_get_args(method_call);
    const gchar* media_id = fl_value_get_string(fl_value_lookup_string(args, "mediaId"));

    // Build file path
    const gchar* base_dir = g_get_user_special_dir(G_USER_DIRECTORY_PICTURES);
    if (!base_dir) {
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
            "THUMBNAIL_ERROR",
            "Could not locate Pictures directory",
            nullptr));
    }

    gchar* media_path = g_build_filename(base_dir, media_id, NULL);

    // Generate thumbnail
    GError* error = NULL;
    GdkPixbuf* thumbnail = generate_thumbnail(media_path, 200, 200, &error);
    g_free(media_path);

    if (error != NULL) {
        g_autoptr(FlValue) error_details = fl_value_new_map();
        fl_value_set(error_details,
                    fl_value_new_string("message"),
                    fl_value_new_string(error->message));
        g_error_free(error);
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
            "THUMBNAIL_ERROR",
            "Failed to generate thumbnail",
            error_details));
    }

    // Convert to bytes
    gchar* buffer;
    gsize buffer_size;
    gdk_pixbuf_save_to_buffer(thumbnail, &buffer, &buffer_size, "png", &error, NULL);
    g_object_unref(thumbnail);

    if (error != NULL) {
        g_autoptr(FlValue) error_details = fl_value_new_map();
        fl_value_set(error_details,
                    fl_value_new_string("message"),
                    fl_value_new_string(error->message));
        g_error_free(error);
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
            "THUMBNAIL_ERROR",
            "Failed to convert thumbnail",
            error_details));
    }

    // Create response
    g_autoptr(FlValue) result = fl_value_new_uint8_list((const uint8_t*)buffer, buffer_size);
    g_free(buffer);

    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Method to check permissions (Linux doesn't require explicit permissions)
static FlMethodResponse* has_permission(FlMethodCall* method_call) {
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Method to request permissions (Linux doesn't require explicit permissions)
static FlMethodResponse* request_permission(FlMethodCall* method_call) {
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Method to get media items in an album
static FlMethodResponse* get_media_in_album(FlMethodCall* method_call) {
    FlValue* args = fl_method_call_get_args(method_call);
    const gchar* album_id = fl_value_get_string(fl_value_lookup_string(args, "albumId"));
    const gchar* media_type = fl_value_get_string(fl_value_lookup_string(args, "mediaType"));
    
    g_autoptr(FlValue) media_list = fl_value_new_list();
    g_autoptr(GFile) directory = g_file_new_for_path(album_id);
    
    g_autoptr(GFileEnumerator) enumerator = 
        g_file_enumerate_children(directory,
                                "standard::*",
                                G_FILE_QUERY_INFO_NONE,
                                nullptr,
                                nullptr);

    while (true) {
        g_autoptr(GFileInfo) info = g_file_enumerator_next_file(enumerator, nullptr, nullptr);
        if (!info) break;

        const char* name = g_file_info_get_name(info);
        const char* content_type = g_file_info_get_content_type(info);
        
        bool is_valid_type = false;
        if (g_strcmp0(media_type, "image") == 0) {
            is_valid_type = g_content_type_is_a(content_type, "image/*");
        } else if (g_strcmp0(media_type, "video") == 0) {
            is_valid_type = g_content_type_is_a(content_type, "video/*");
        }

        if (is_valid_type) {
            g_autoptr(GFile) file = g_file_get_child(directory, name);
            g_autofree char* path = g_file_get_path(file);
            
            g_autoptr(FlValue) media_info = fl_value_new_map();
            
            // Get file info
            g_autoptr(GFileInfo) file_info = 
                g_file_query_info(file,
                                "standard::*,time::modified",
                                G_FILE_QUERY_INFO_NONE,
                                nullptr,
                                nullptr);
                                
            guint64 size = g_file_info_get_size(file_info);
            guint64 mtime = g_file_info_get_attribute_uint64(file_info, "time::modified");
            
            // Add basic file information
            fl_value_set(media_info, 
                        fl_value_new_string("id"),
                        fl_value_new_string(path));
            fl_value_set(media_info,
                        fl_value_new_string("name"),
                        fl_value_new_string(name));
            fl_value_set(media_info,
                        fl_value_new_string("path"),
                        fl_value_new_string(path));
            fl_value_set(media_info,
                        fl_value_new_string("dateAdded"),
                        fl_value_new_int(mtime));
            fl_value_set(media_info,
                        fl_value_new_string("size"),
                        fl_value_new_int(size));
            fl_value_set(media_info,
                        fl_value_new_string("type"),
                        fl_value_new_string(media_type));
            
            // Get image dimensions using GdkPixbuf
            if (g_content_type_is_a(content_type, "image/*")) {
                g_autoptr(GdkPixbuf) pixbuf = gdk_pixbuf_new_from_file(path, nullptr);
                if (pixbuf) {
                    fl_value_set(media_info, 
                                fl_value_new_string("width"),
                                fl_value_new_int(gdk_pixbuf_get_width(pixbuf)));
                    fl_value_set(media_info,
                                fl_value_new_string("height"), 
                                fl_value_new_int(gdk_pixbuf_get_height(pixbuf)));
                } else {
                    fl_value_set(media_info,
                                fl_value_new_string("width"),
                                fl_value_new_int(0));
                    fl_value_set(media_info,
                                fl_value_new_string("height"),
                                fl_value_new_int(0));
                }
            }
            
            fl_value_append(media_list, media_info);
        }
    }

    return FL_METHOD_RESPONSE(fl_method_success_response_new(media_list));
}

// Method handler implementation
static FlMethodResponse* get_albums(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  const gchar* media_type = nullptr;
  
  // Safely get media type from arguments
  if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    FlValue* media_type_value = fl_value_lookup_string(args, "mediaType");
    if (media_type_value != nullptr) {
      media_type = fl_value_get_string(media_type_value);
    }
  }
  
  // Get Pictures directory path
  const gchar* pictures_dir = g_get_user_special_dir(G_USER_DIRECTORY_PICTURES);
  if (!pictures_dir) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "DIRECTORY_ERROR",
      "Could not locate Pictures directory",
      nullptr));
  }
  
  // Create albums array
  g_autoptr(FlValue) albums = fl_value_new_list();
  
  // Process directories with media type filter
  process_directory(pictures_dir, media_type, albums);
  
  return FL_METHOD_RESPONSE(fl_method_success_response_new(albums));
}

// Called when a method call is received from Flutter.
static void photo_gallery_pro_plugin_handle_method_call(
    PhotoGalleryProPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getAlbums") == 0) {
    response = get_albums(method_call);
  } else if (strcmp(method, "getAlbumThumbnail") == 0) {
    response = get_album_thumbnail(method_call);
  } else if (strcmp(method, "getThumbnail") == 0) {
    response = get_thumbnail(method_call);
  } else if (strcmp(method, "getMediaInAlbum") == 0) {
    response = get_media_in_album(method_call);
  } else if (strcmp(method, "hasPermission") == 0) {
    response = has_permission(method_call);
  } else if (strcmp(method, "requestPermission") == 0) {
    response = request_permission(method_call);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void photo_gallery_pro_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(photo_gallery_pro_plugin_parent_class)->dispose(object);
}

static void photo_gallery_pro_plugin_class_init(PhotoGalleryProPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = photo_gallery_pro_plugin_dispose;
}

static void photo_gallery_pro_plugin_init(PhotoGalleryProPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  PhotoGalleryProPlugin* plugin = PHOTO_GALLERY_PRO_PLUGIN(user_data);
  photo_gallery_pro_plugin_handle_method_call(plugin, method_call);
}

void photo_gallery_pro_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  PhotoGalleryProPlugin* plugin = PHOTO_GALLERY_PRO_PLUGIN(
      g_object_new(photo_gallery_pro_plugin_get_type(), nullptr));
      
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                           "photo_gallery_pro",
                           FL_METHOD_CODEC(codec));
                           
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                           g_object_ref(plugin),
                                           g_object_unref);

  g_object_unref(plugin);
}
