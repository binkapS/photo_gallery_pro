#include "include/photo_gallery_pro/photo_gallery_pro_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>
#include <gio/gio.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <string.h>
#include <sys/stat.h>
#include <dirent.h>

#include <cstring>

#include "photo_gallery_pro_plugin_private.h"

#define PHOTO_GALLERY_PRO_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), photo_gallery_pro_plugin_get_type(), \
                              PhotoGalleryProPlugin))

struct _PhotoGalleryProPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(PhotoGalleryProPlugin, photo_gallery_pro_plugin, g_object_get_type())

// Forward declarations of helper functions
static int get_media_count(const gchar* dir_path, const gchar* media_type);
static void process_directory(const gchar* dir_path, const gchar* media_type, FlValue* albums);
static gchar* get_first_media_in_album(const gchar* album_id, const gchar* media_type);

// Helper function implementations
static int get_media_count(const gchar* dir_path, const gchar* media_type) {
    DIR* dir = opendir(dir_path);
    if (dir == NULL) return 0;
    
    int count = 0;
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_type == DT_REG) {
            gchar* extension = strrchr(entry->d_name, '.');
            if (extension != NULL) {
                if (g_strcmp0(media_type, "image") == 0) {
                    if (g_ascii_strcasecmp(extension, ".jpg") == 0 ||
                        g_ascii_strcasecmp(extension, ".jpeg") == 0 ||
                        g_ascii_strcasecmp(extension, ".png") == 0) {
                        count++;
                    }
                } else if (g_strcmp0(media_type, "video") == 0) {
                    if (g_ascii_strcasecmp(extension, ".mp4") == 0 ||
                        g_ascii_strcasecmp(extension, ".mov") == 0 ||
                        g_ascii_strcasecmp(extension, ".avi") == 0) {
                        count++;
                    }
                }
            }
        }
    }
    
    closedir(dir);
    return count;
}

static void process_directory(const gchar* dir_path, const gchar* media_type, FlValue* albums) {
    if (dir_path == NULL) return;
    
    DIR* dir = opendir(dir_path);
    if (dir == NULL) return;
    
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_type == DT_DIR && 
            g_strcmp0(entry->d_name, ".") != 0 && 
            g_strcmp0(entry->d_name, "..") != 0) {
            
            FlValue* album = fl_value_new_map();
            
            // Set values directly with fl_value_set
            fl_value_set(album,
                        fl_value_new_string("id"),
                        fl_value_new_string(entry->d_name));
            fl_value_set(album,
                        fl_value_new_string("name"),
                        fl_value_new_string(entry->d_name));
            fl_value_set(album,
                        fl_value_new_string("type"),
                        fl_value_new_string(media_type));
            
            // Get media count
            gchar* full_path = g_build_filename(dir_path, entry->d_name, NULL);
            int count = get_media_count(full_path, media_type);
            fl_value_set(album,
                        fl_value_new_string("count"),
                        fl_value_new_int(count));
            g_free(full_path);
            
            // Append to albums list
            fl_value_append(albums, album);
        }
    }
    
    closedir(dir);
}

static gchar* get_first_media_in_album(const gchar* album_id, const gchar* media_type) {
    const gchar* base_dir = g_strcmp0(media_type, "image") == 0 ?
        g_get_user_special_dir(G_USER_DIRECTORY_PICTURES) :
        g_get_user_special_dir(G_USER_DIRECTORY_VIDEOS);
    
    if (base_dir == NULL) return NULL;
    
    gchar* album_path = g_build_filename(base_dir, album_id, NULL);
    DIR* dir = opendir(album_path);
    if (dir == NULL) {
        g_free(album_path);
        return NULL;
    }
    
    struct dirent* entry;
    gchar* result = NULL;
    
    while ((entry = readdir(dir)) != NULL && result == NULL) {
        if (entry->d_type == DT_REG) {
            gchar* extension = strrchr(entry->d_name, '.');
            if (extension != NULL) {
                if (g_strcmp0(media_type, "image") == 0) {
                    if (g_ascii_strcasecmp(extension, ".jpg") == 0 ||
                        g_ascii_strcasecmp(extension, ".jpeg") == 0 ||
                        g_ascii_strcasecmp(extension, ".png") == 0) {
                        result = g_build_filename(album_path, entry->d_name, NULL);
                    }
                } else if (g_strcmp0(media_type, "video") == 0) {
                    if (g_ascii_strcasecmp(extension, ".mp4") == 0 ||
                        g_ascii_strcasecmp(extension, ".mov") == 0 ||
                        g_ascii_strcasecmp(extension, ".avi") == 0) {
                        result = g_build_filename(album_path, entry->d_name, NULL);
                    }
                }
            }
        }
    }
    
    closedir(dir);
    g_free(album_path);
    return result;
}

static FlMethodResponse* get_albums(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  const gchar* media_type = fl_value_get_string(fl_value_lookup_string(args, "mediaType"));
  
  g_autoptr(FlValue) albums = fl_value_new_list();
  
  // Get user's media directories
  const gchar* pictures_dir = g_get_user_special_dir(G_USER_DIRECTORY_PICTURES);
  const gchar* videos_dir = g_get_user_special_dir(G_USER_DIRECTORY_VIDEOS);
  
  // Process directories based on media type
  if (media_type == NULL || strcmp(media_type, "image") == 0) {
    process_directory(pictures_dir, "image", albums);
  }
  
  if (media_type == NULL || strcmp(media_type, "video") == 0) {
    process_directory(videos_dir, "video", albums);
  }
  
  return FL_METHOD_RESPONSE(fl_method_success_response_new(albums));
}

static FlMethodResponse* get_album_thumbnail(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  const gchar* album_id = fl_value_get_string(fl_value_lookup_string(args, "albumId"));
  const gchar* media_type = fl_value_get_string(fl_value_lookup_string(args, "mediaType"));
  
  // Get first media file in album
  gchar* first_media = get_first_media_in_album(album_id, media_type);
  if (first_media == NULL) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "THUMBNAIL_ERROR",
      "No media found in album",
      NULL));
  }
  
  // Generate thumbnail
  GError* error = NULL;
  GdkPixbuf* pixbuf = gdk_pixbuf_new_from_file_at_scale(
    first_media,
    320,  // width
    320,  // height
    TRUE, // preserve aspect ratio
    &error
  );
  
  g_free(first_media);
  
  if (error != NULL) {
    g_autoptr(FlValue) error_details = fl_value_new_map();
    // Create and set error message
    fl_value_set(error_details,
                 fl_value_new_string("message"),
                 fl_value_new_string(error->message));
    g_error_free(error);
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "THUMBNAIL_ERROR",
        "Failed to generate thumbnail",
        error_details));
  }
  
  // Convert to JPEG
  gchar* buffer;
  gsize buffer_size;
  gdk_pixbuf_save_to_buffer(
    pixbuf,
    &buffer,
    &buffer_size,
    "jpeg",
    &error,
    "quality", "90",
    NULL
  );
  
  g_object_unref(pixbuf);
  
  if (error != NULL) {
    g_error_free(error);
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "THUMBNAIL_ERROR",
      "Failed to encode thumbnail",
      NULL));
  }
  
  g_autoptr(FlValue) result = fl_value_new_uint8_list((const uint8_t*)buffer, buffer_size);
  g_free(buffer);
  
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Add missing getThumbnail implementation
static FlMethodResponse* get_thumbnail(FlMethodCall* method_call) {
    FlValue* args = fl_method_call_get_args(method_call);
    const gchar* media_id = fl_value_get_string(fl_value_lookup_string(args, "mediaId"));
    const gchar* media_type = fl_value_get_string(fl_value_lookup_string(args, "mediaType"));
    
    if (media_id == NULL || media_type == NULL) {
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
            "INVALID_ARGUMENTS",
            "Media ID and type are required",
            NULL));
    }
    
    // Get the file path based on media type and ID
    const gchar* base_dir = g_strcmp0(media_type, "image") == 0 ?
        g_get_user_special_dir(G_USER_DIRECTORY_PICTURES) :
        g_get_user_special_dir(G_USER_DIRECTORY_VIDEOS);
        
    if (base_dir == NULL) {
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
            "PATH_ERROR",
            "Could not locate media directory",
            NULL));
    }
    
    gchar* file_path = g_build_filename(base_dir, media_id, NULL);
    
    // Generate thumbnail
    GError* error = NULL;
    GdkPixbuf* pixbuf = gdk_pixbuf_new_from_file_at_scale(
        file_path,
        320,  // width
        320,  // height
        TRUE, // preserve aspect ratio
        &error
    );
    
    g_free(file_path);
    
    if (error != NULL) {
        g_autoptr(FlValue) error_details = fl_value_new_map();
        // Create and set error message
        fl_value_set(error_details,
                     fl_value_new_string("message"),
                     fl_value_new_string(error->message));
        g_error_free(error);
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
            "THUMBNAIL_ERROR",
            "Failed to generate thumbnail",
            error_details));
    }
    
    // Convert to JPEG
    gchar* buffer;
    gsize buffer_size;
    gdk_pixbuf_save_to_buffer(
        pixbuf,
        &buffer,
        &buffer_size,
        "jpeg",
        &error,
        "quality", "90",
        NULL
    );
    
    g_object_unref(pixbuf);
    
    if (error != NULL) {
        g_error_free(error);
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
            "THUMBNAIL_ERROR",
            "Failed to encode thumbnail",
            NULL));
    }
    
    g_autoptr(FlValue) result = fl_value_new_uint8_list((const uint8_t*)buffer, buffer_size);
    g_free(buffer);
    
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
    const gchar* method = fl_method_call_get_name(method_call);
    
    g_autoptr(FlMethodResponse) response = NULL;
    if (g_strcmp0(method, "getAlbums") == 0) {
        response = get_albums(method_call);
    } else if (g_strcmp0(method, "getAlbumThumbnail") == 0) {
        response = get_album_thumbnail(method_call);
    } else if (g_strcmp0(method, "getThumbnail") == 0) {
        response = get_thumbnail(method_call);
    } else if (g_strcmp0(method, "hasPermission") == 0) {
        // Linux doesn't require explicit permissions for accessing Pictures/Videos
        g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    } else if (g_strcmp0(method, "requestPermission") == 0) {
        // Linux doesn't require explicit permissions
        g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    } else {
        response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    }
    
    fl_method_call_respond(method_call, response, NULL);
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
