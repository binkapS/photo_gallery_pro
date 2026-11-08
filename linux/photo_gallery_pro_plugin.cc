#include "include/photo_gallery_pro/photo_gallery_pro_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>
#include <gio/gio.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <string.h>
#include <stdlib.h>
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

// --- Media kind helpers ------------------------------------------------

typedef enum {
  MEDIA_KIND_NONE,
  MEDIA_KIND_IMAGE,
  MEDIA_KIND_VIDEO,
} MediaKind;

static gboolean ext_is(const gchar* ext, const gchar* name) {
  return g_ascii_strcasecmp(ext, name) == 0;
}

static gboolean is_image_extension(const gchar* ext) {
  return ext_is(ext, "jpg") || ext_is(ext, "jpeg") || ext_is(ext, "png") ||
         ext_is(ext, "gif") || ext_is(ext, "webp") || ext_is(ext, "tiff") ||
         ext_is(ext, "tif") || ext_is(ext, "heic") || ext_is(ext, "heif") ||
         ext_is(ext, "bmp");
}

static gboolean is_video_extension(const gchar* ext) {
  return ext_is(ext, "mp4") || ext_is(ext, "avi") || ext_is(ext, "mkv") ||
         ext_is(ext, "mov") || ext_is(ext, "webm") || ext_is(ext, "m4v") ||
         ext_is(ext, "mpeg") || ext_is(ext, "mpg") || ext_is(ext, "3gp");
}

static const gchar* extension_of(const gchar* filename) {
  const gchar* dot = strrchr(filename, '.');
  return dot ? dot + 1 : "";
}

static MediaKind classify_file(const gchar* filename) {
  const gchar* ext = extension_of(filename);
  if (is_image_extension(ext)) return MEDIA_KIND_IMAGE;
  if (is_video_extension(ext)) return MEDIA_KIND_VIDEO;
  return MEDIA_KIND_NONE;
}

static const char* mime_for_extension(const gchar* ext) {
  if (!ext || !*ext) return "application/octet-stream";
  g_autofree gchar* lower = g_ascii_strdown(ext, -1);
  if (g_strcmp0(lower, "jpg") == 0 || g_strcmp0(lower, "jpeg") == 0)
    return "image/jpeg";
  if (g_strcmp0(lower, "png") == 0) return "image/png";
  if (g_strcmp0(lower, "gif") == 0) return "image/gif";
  if (g_strcmp0(lower, "webp") == 0) return "image/webp";
  if (g_strcmp0(lower, "tiff") == 0 || g_strcmp0(lower, "tif") == 0)
    return "image/tiff";
  if (g_strcmp0(lower, "heic") == 0) return "image/heic";
  if (g_strcmp0(lower, "heif") == 0) return "image/heif";
  if (g_strcmp0(lower, "bmp") == 0) return "image/bmp";
  if (g_strcmp0(lower, "mp4") == 0) return "video/mp4";
  if (g_strcmp0(lower, "avi") == 0) return "video/x-msvideo";
  if (g_strcmp0(lower, "mkv") == 0) return "video/x-matroska";
  if (g_strcmp0(lower, "mov") == 0) return "video/quicktime";
  if (g_strcmp0(lower, "webm") == 0) return "video/webm";
  if (g_strcmp0(lower, "m4v") == 0) return "video/mp4";
  if (g_strcmp0(lower, "mpeg") == 0 || g_strcmp0(lower, "mpg") == 0)
    return "video/mpeg";
  if (g_strcmp0(lower, "3gp") == 0) return "video/3gpp";
  return "application/octet-stream";
}

// --- Argument helpers --------------------------------------------------

static const gchar* get_string_arg(FlValue* args, const gchar* key) {
  if (args == NULL || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return NULL;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == NULL || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return NULL;
  }
  return fl_value_get_string(value);
}

static gboolean get_int_arg(FlValue* args, const gchar* key, gint64* out) {
  if (args == NULL || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FALSE;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == NULL || fl_value_get_type(value) != FL_VALUE_TYPE_INT) {
    return FALSE;
  }
  *out = fl_value_get_int(value);
  return TRUE;
}

static gint clamp_dimension(gint64 value, gint fallback) {
  if (value <= 0) return fallback;
  if (value > 4096) return 4096;
  return (gint)value;
}

// --- Album path helpers ------------------------------------------------

// Resolves an album id (basename under ~/Pictures, as returned by
// getAlbums) to a full directory path. A full path is accepted as-is for
// backward compatibility.
static gchar* resolve_album_dir(const gchar* album_id) {
  if (album_id == NULL || !*album_id) return NULL;
  if (g_str_has_prefix(album_id, G_DIR_SEPARATOR_S)) {
    return g_strdup(album_id);
  }
  const gchar* pictures_dir =
      g_get_user_special_dir(G_USER_DIRECTORY_PICTURES);
  if (pictures_dir == NULL) return NULL;
  return g_build_filename(pictures_dir, album_id, NULL);
}

// Resolves a media id to a full file path. A media id containing a '/'
// is treated as a path; otherwise the file is looked up as
// ~/Pictures/<mediaId> first, then one level deep in each album
// directory under ~/Pictures.
static gchar* resolve_media_path(const gchar* media_id) {
  if (media_id == NULL || !*media_id) return NULL;
  if (strchr(media_id, '/') != NULL) {
    return g_strdup(media_id);
  }
  const gchar* pictures_dir =
      g_get_user_special_dir(G_USER_DIRECTORY_PICTURES);
  if (pictures_dir == NULL) return NULL;

  g_autofree gchar* candidate =
      g_build_filename(pictures_dir, media_id, NULL);
  if (g_file_test(candidate, G_FILE_TEST_IS_REGULAR)) {
    return g_strdup(candidate);
  }

  DIR* dir = opendir(pictures_dir);
  if (dir == NULL) return NULL;
  gchar* result = NULL;
  struct dirent* entry;
  while ((entry = readdir(dir)) != NULL && result == NULL) {
    if (entry->d_type != DT_UNKNOWN && entry->d_type != DT_DIR &&
        entry->d_type != DT_LNK) {
      continue;
    }
    if (g_strcmp0(entry->d_name, ".") == 0 ||
        g_strcmp0(entry->d_name, "..") == 0) {
      continue;
    }
    g_autofree gchar* album_path =
        g_build_filename(pictures_dir, entry->d_name, NULL);
    g_autofree gchar* nested =
        g_build_filename(album_path, media_id, NULL);
    if (g_file_test(nested, G_FILE_TEST_IS_REGULAR)) {
      result = g_strdup(nested);
    }
  }
  closedir(dir);
  return result;
}

// Scans one album directory, counting image/video files, tracking the
// newest mtime (seconds) and the newest file's basename.
typedef struct {
  gint images;
  gint videos;
  gint64 last_modified_sec;
  gchar* newest_basename;
} AlbumContents;

static void scan_album_dir(const gchar* dir_path, AlbumContents* contents) {
  DIR* dir = opendir(dir_path);
  if (dir == NULL) return;

  struct dirent* entry;
  while ((entry = readdir(dir)) != NULL) {
    if (g_strcmp0(entry->d_name, ".") == 0 ||
        g_strcmp0(entry->d_name, "..") == 0) {
      continue;
    }
    if (entry->d_type != DT_UNKNOWN && entry->d_type != DT_REG &&
        entry->d_type != DT_LNK) {
      continue;
    }
    MediaKind kind = classify_file(entry->d_name);
    if (kind == MEDIA_KIND_NONE) continue;
    if (kind == MEDIA_KIND_IMAGE) {
      contents->images++;
    } else {
      contents->videos++;
    }

    g_autofree gchar* full_path =
        g_build_filename(dir_path, entry->d_name, NULL);
    struct stat st;
    if (stat(full_path, &st) == 0 && S_ISREG(st.st_mode) &&
        st.st_mtime > contents->last_modified_sec) {
      contents->last_modified_sec = (gint64)st.st_mtime;
      g_free(contents->newest_basename);
      contents->newest_basename = g_strdup(entry->d_name);
    }
  }
  closedir(dir);
}

// Finds the newest media file in an album (full path or NULL). The album
// id is standardized to a basename under ~/Pictures (a full path is also
// accepted). A NULL/mixed media type matches both images and videos.
static gchar* get_first_media_in_album(const gchar* album_id,
                                        const gchar* media_type) {
  g_autofree gchar* album_path = resolve_album_dir(album_id);
  if (album_path == NULL) return NULL;

  DIR* dir = opendir(album_path);
  if (dir == NULL) return NULL;

  gboolean want_image = (g_strcmp0(media_type, "image") == 0);
  gboolean want_video = (g_strcmp0(media_type, "video") == 0);
  gboolean want_all = !want_image && !want_video;

  gchar* result = NULL;
  gint64 best_mtime = -1;
  struct dirent* entry;
  while ((entry = readdir(dir)) != NULL) {
    if (entry->d_type != DT_UNKNOWN && entry->d_type != DT_REG &&
        entry->d_type != DT_LNK) {
      continue;
    }
    MediaKind kind = classify_file(entry->d_name);
    if (kind == MEDIA_KIND_NONE) continue;
    if ((want_image && kind != MEDIA_KIND_IMAGE) ||
        (want_video && kind != MEDIA_KIND_VIDEO) ||
        (!want_all && kind == MEDIA_KIND_NONE)) {
      continue;
    }
    g_autofree gchar* full_path =
        g_build_filename(album_path, entry->d_name, NULL);
    struct stat st;
    gint64 mtime = 0;
    if (stat(full_path, &st) == 0 && S_ISREG(st.st_mode)) {
      mtime = (gint64)st.st_mtime;
    }
    if (result == NULL || mtime > best_mtime) {
      g_free(result);
      result = g_strdup(full_path);
      best_mtime = mtime;
    }
  }
  closedir(dir);
  return result;
}

// --- Thumbnails --------------------------------------------------------

// Generates a scaled thumbnail in a single one-pass resize.
static GdkPixbuf* generate_thumbnail(const gchar* file_path, int width,
                                     int height, GError** error) {
  if (width <= 0) width = 512;
  if (height <= 0) height = 512;
  if (width > 4096) width = 4096;
  if (height > 4096) height = 4096;
  return gdk_pixbuf_new_from_file_at_scale(file_path, width, height, TRUE,
                                           error);
}

// Builds the canonical {data, width, height, format} thumbnail map for a
// file. Thumbnails are always encoded as JPEG and report "jpeg", matching
// Android/iOS. Errors are returned via [error] (set on failure).
static FlValue* build_thumbnail_map(const gchar* file_path, int width,
                                    int height, GError** error) {
  g_autoptr(GdkPixbuf) pixbuf =
      generate_thumbnail(file_path, width, height, error);
  if (pixbuf == NULL) return NULL;

  gchar* buffer = NULL;
  gsize buffer_size = 0;
  if (!gdk_pixbuf_save_to_buffer(pixbuf, &buffer, &buffer_size, "jpeg",
                                 error, NULL)) {
    return NULL;
  }
  int final_width = gdk_pixbuf_get_width(pixbuf);
  int final_height = gdk_pixbuf_get_height(pixbuf);

  FlValue* map = fl_value_new_map();
  fl_value_set(map, fl_value_new_string("data"),
               fl_value_new_uint8_list((const uint8_t*)buffer, buffer_size));
  fl_value_set(map, fl_value_new_string("width"),
               fl_value_new_int(final_width));
  fl_value_set(map, fl_value_new_string("height"),
               fl_value_new_int(final_height));
  fl_value_set(map, fl_value_new_string("format"),
               fl_value_new_string("jpeg"));
  g_free(buffer);
  return map;
}

// Reads thumbnail size arguments (defaults: 512x512, capped at 4096).
static void parse_thumbnail_size(FlValue* args, int* width_out,
                                 int* height_out) {
  gint64 width_arg = 512, height_arg = 512;
  get_int_arg(args, "width", &width_arg);
  get_int_arg(args, "height", &height_arg);
  *width_out = clamp_dimension(width_arg, 512);
  *height_out = clamp_dimension(height_arg, 512);
}

// --- getAlbums ----------------------------------------------------------

static FlMethodResponse* get_albums(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  const gchar* media_type = get_string_arg(args, "mediaType");
  gint64 offset = 0;
  gint64 limit = -1;
  get_int_arg(args, "offset", &offset);
  get_int_arg(args, "limit", &limit);
  if (offset < 0) offset = 0;

  const gchar* pictures_dir =
      g_get_user_special_dir(G_USER_DIRECTORY_PICTURES);
  if (pictures_dir == NULL) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "DIRECTORY_ERROR", "Could not locate Pictures directory", NULL));
  }

  gboolean want_image = (g_strcmp0(media_type, "image") == 0);
  gboolean want_video = (g_strcmp0(media_type, "video") == 0);

  // Collect matching albums, then apply offset/limit.
  g_autoptr(FlValue) collected = fl_value_new_list();
  DIR* dir = opendir(pictures_dir);
  if (dir == NULL) {
    // No Pictures directory (yet): treat as an empty gallery, matching
    // the previous behavior.
    g_autoptr(FlValue) empty = fl_value_new_list();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(empty));
  }

  struct dirent* entry;
  while ((entry = readdir(dir)) != NULL) {
    if (entry->d_type != DT_UNKNOWN && entry->d_type != DT_DIR &&
        entry->d_type != DT_LNK) {
      continue;
    }
    if (g_strcmp0(entry->d_name, ".") == 0 ||
        g_strcmp0(entry->d_name, "..") == 0) {
      continue;
    }

    g_autofree gchar* full_path =
        g_build_filename(pictures_dir, entry->d_name, NULL);
    struct stat st;
    if (stat(full_path, &st) != 0 || !S_ISDIR(st.st_mode)) {
      continue;
    }

    AlbumContents contents;
    memset(&contents, 0, sizeof(contents));
    scan_album_dir(full_path, &contents);

    const gchar* album_type;
    if (contents.images > 0 && contents.videos > 0) {
      album_type = "mixed";
    } else if (contents.images > 0) {
      album_type = "image";
    } else if (contents.videos > 0) {
      album_type = "video";
    } else {
      continue;
    }

    gint count;
    if (want_image) {
      count = contents.images;
    } else if (want_video) {
      count = contents.videos;
    } else {
      count = contents.images + contents.videos;
    }
    if (count == 0) {
      g_free(contents.newest_basename);
      continue;
    }

    g_autoptr(FlValue) album = fl_value_new_map();
    fl_value_set(album, fl_value_new_string("id"),
                 fl_value_new_string(entry->d_name));
    fl_value_set(album, fl_value_new_string("name"),
                 fl_value_new_string(entry->d_name));
    fl_value_set(album, fl_value_new_string("count"),
                 fl_value_new_int(count));
    fl_value_set(album, fl_value_new_string("type"),
                 fl_value_new_string(album_type));
    fl_value_set(album, fl_value_new_string("path"),
                 fl_value_new_string(full_path));
    if (contents.newest_basename != NULL) {
      fl_value_set(album, fl_value_new_string("thumbnailMediaId"),
                   fl_value_new_string(contents.newest_basename));
    }
    if (contents.last_modified_sec > 0) {
      fl_value_set(album, fl_value_new_string("lastModified"),
                   fl_value_new_int(contents.last_modified_sec));
    }
    fl_value_append(collected, album);
    g_free(contents.newest_basename);
  }
  closedir(dir);

  g_autoptr(FlValue) result = fl_value_new_list();
  size_t total = fl_value_get_length(collected);
  size_t begin = (size_t)MIN(offset, (gint64)total);
  size_t remaining = (limit < 0) ? (total - begin) : (size_t)MIN(
      limit, (gint64)(total - begin));
  for (size_t i = 0; i < remaining; i++) {
    fl_value_append(result, fl_value_get_list_value(collected, begin + i));
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// --- getMediaInAlbum ----------------------------------------------------

typedef struct {
  gchar* name;    // basename / id
  gchar* path;    // full path
  gchar* mime;
  gchar* kind;    // "image" / "video"
  gint64 date_added;
  gint64 size;
  gint width;
  gint height;
  gint64 duration;
} MediaEntry;

static void media_entry_free(gpointer data) {
  MediaEntry* entry = (MediaEntry*)data;
  g_free(entry->name);
  g_free(entry->path);
  g_free(entry->mime);
  g_free(entry->kind);
  g_free(entry);
}

static int media_entry_compare(gconstpointer a, gconstpointer b,
                               gpointer user_data) {
  const MediaEntry* ea = (const MediaEntry*)a;
  const MediaEntry* eb = (const MediaEntry*)b;
  const gchar* mode = (const gchar*)user_data;
  int cmp = 0;

  if (g_strcmp0(mode, "dateAddedAsc") == 0) {
    cmp = (ea->date_added > eb->date_added) - (ea->date_added < eb->date_added);
  } else if (g_strcmp0(mode, "sizeDesc") == 0) {
    cmp = (eb->size > ea->size) - (eb->size < ea->size);
  } else if (g_strcmp0(mode, "nameAsc") == 0) {
    cmp = g_strcmp0(ea->name, eb->name);
  } else {
    // dateAddedDesc (default; newest first)
    cmp = (eb->date_added > ea->date_added) - (eb->date_added < ea->date_added);
  }
  if (cmp == 0 && g_strcmp0(mode, "nameAsc") != 0) {
    cmp = g_strcmp0(ea->name, eb->name);
  }
  return cmp;
}

static FlMethodResponse* get_media_in_album(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  const gchar* album_id = get_string_arg(args, "albumId");
  const gchar* media_type = get_string_arg(args, "mediaType");
  const gchar* sort_mode = get_string_arg(args, "sort");
  gint64 offset = 0;
  gint64 limit = -1;
  get_int_arg(args, "offset", &offset);
  get_int_arg(args, "limit", &limit);
  if (offset < 0) offset = 0;

  g_autofree gchar* album_dir = resolve_album_dir(album_id);
  if (album_dir == NULL) {
    // No such album: return an empty list (previous behavior).
    g_autoptr(FlValue) empty = fl_value_new_list();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(empty));
  }

  g_autoptr(GFile) directory = g_file_new_for_path(album_dir);
  g_autoptr(GError) enum_error = NULL;
  g_autoptr(GFileEnumerator) enumerator = g_file_enumerate_children(
      directory, "standard::*,time::modified", G_FILE_QUERY_INFO_NONE, NULL,
      &enum_error);
  if (enumerator == NULL) {
    g_autoptr(FlValue) empty = fl_value_new_list();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(empty));
  }

  gboolean want_image = (g_strcmp0(media_type, "image") == 0);
  gboolean want_video = (g_strcmp0(media_type, "video") == 0);

  g_autoptr(GPtrArray) entries =
      g_ptr_array_new_with_free_func(media_entry_free);

  while (TRUE) {
    g_autoptr(GError) next_error = NULL;
    g_autoptr(GFileInfo) info =
        g_file_enumerator_next_file(enumerator, NULL, &next_error);
    if (info == NULL) {
      break;
    }
    const char* name = g_file_info_get_name(info);
    if (name == NULL) continue;

    MediaKind kind = classify_file(name);
    if (kind == MEDIA_KIND_NONE) continue;
    if (want_image && kind != MEDIA_KIND_IMAGE) continue;
    if (want_video && kind != MEDIA_KIND_VIDEO) continue;

    g_autoptr(GFile) file = g_file_get_child(directory, name);
    g_autofree char* path = g_file_get_path(file);
    if (path == NULL) continue;

    MediaEntry* entry = g_new0(MediaEntry, 1);
    entry->name = g_strdup(name);
    entry->path = g_strdup(path);
    entry->mime = g_strdup(mime_for_extension(extension_of(name)));
    entry->kind = g_strdup(kind == MEDIA_KIND_IMAGE ? "image" : "video");
    entry->size = (gint64)g_file_info_get_size(info);
    entry->duration = 0;

    // time::modified is in microseconds; Dart expects seconds.
    guint64 modified_us = g_file_info_get_attribute_uint64(
        info, G_FILE_ATTRIBUTE_TIME_MODIFIED);
    entry->date_added =
        (gint64)(modified_us / G_TIME_SPAN_SECOND);

    if (kind == MEDIA_KIND_IMAGE) {
      g_autoptr(GdkPixbuf) pixbuf =
          gdk_pixbuf_new_from_file(path, NULL);
      if (pixbuf != NULL) {
        entry->width = gdk_pixbuf_get_width(pixbuf);
        entry->height = gdk_pixbuf_get_height(pixbuf);
      }
    }
    g_ptr_array_insert(entries, -1, entry);
  }

  g_ptr_array_sort_with_data(entries, media_entry_compare,
                             (gpointer)(sort_mode != NULL ? sort_mode
                                                          : "dateAddedDesc"));

  g_autoptr(FlValue) media_list = fl_value_new_list();
  size_t total = entries->len;
  size_t begin = (size_t)MIN(offset, (gint64)total);
  size_t remaining = (limit < 0) ? (total - begin) : (size_t)MIN(
      limit, (gint64)(total - begin));
  for (size_t i = 0; i < remaining; i++) {
    MediaEntry* entry = (MediaEntry*)g_ptr_array_index(entries, begin + i);
    g_autoptr(FlValue) media_info = fl_value_new_map();
    fl_value_set(media_info, fl_value_new_string("id"),
                 fl_value_new_string(entry->name));
    fl_value_set(media_info, fl_value_new_string("uri"),
                 fl_value_new_string(entry->name));
    fl_value_set(media_info, fl_value_new_string("name"),
                 fl_value_new_string(entry->name));
    fl_value_set(media_info, fl_value_new_string("mimeType"),
                 fl_value_new_string(entry->mime));
    fl_value_set(media_info, fl_value_new_string("type"),
                 fl_value_new_string(entry->kind));
    fl_value_set(media_info, fl_value_new_string("dateAdded"),
                 fl_value_new_int(entry->date_added));
    fl_value_set(media_info, fl_value_new_string("dateModified"),
                 fl_value_new_int(entry->date_added));
    fl_value_set(media_info, fl_value_new_string("size"),
                 fl_value_new_int(entry->size));
    fl_value_set(media_info, fl_value_new_string("width"),
                 fl_value_new_int(entry->width));
    fl_value_set(media_info, fl_value_new_string("height"),
                 fl_value_new_int(entry->height));
    fl_value_set(media_info, fl_value_new_string("duration"),
                 fl_value_new_int(entry->duration));
    fl_value_set(media_info, fl_value_new_string("filePath"),
                 fl_value_new_string(entry->path));
    fl_value_append(media_list, media_info);
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(media_list));
}

// --- Thumbnails --------------------------------------------------------

static FlMethodResponse* get_thumbnail(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  const gchar* media_id = get_string_arg(args, "mediaId");

  int width = 512, height = 512;
  parse_thumbnail_size(args, &width, &height);

  g_autofree gchar* file_path = resolve_media_path(media_id);
  if (file_path == NULL || !g_file_test(file_path, G_FILE_TEST_IS_REGULAR)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "NOT_FOUND", "Media not found", NULL));
  }

  g_autoptr(GError) error = NULL;
  g_autoptr(FlValue) map =
      build_thumbnail_map(file_path, width, height, &error);
  if (map == NULL) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "THUMBNAIL_ERROR", "Failed to generate thumbnail",
        error ? fl_value_new_string(error->message) : NULL));
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(map));
}

static FlMethodResponse* get_album_thumbnail(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  const gchar* album_id = get_string_arg(args, "albumId");
  const gchar* media_type = get_string_arg(args, "mediaType");

  int width = 512, height = 512;
  parse_thumbnail_size(args, &width, &height);

  g_autofree gchar* media_path =
      get_first_media_in_album(album_id, media_type);
  if (media_path == NULL) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "NOT_FOUND", "No media found in album", NULL));
  }

  g_autoptr(GError) error = NULL;
  g_autoptr(FlValue) map =
      build_thumbnail_map(media_path, width, height, &error);
  if (map == NULL) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "THUMBNAIL_ERROR", "Failed to generate thumbnail",
        error ? fl_value_new_string(error->message) : NULL));
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(map));
}

static FlMethodResponse* get_thumbnail_batch(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);

  int width = 512, height = 512;
  parse_thumbnail_size(args, &width, &height);

  g_autoptr(FlValue) result = fl_value_new_map();
  if (args == NULL || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  FlValue* ids_value = fl_value_lookup_string(args, "mediaIds");
  if (ids_value == NULL ||
      fl_value_get_type(ids_value) != FL_VALUE_TYPE_LIST) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  size_t count = fl_value_get_length(ids_value);
  for (size_t i = 0; i < count; i++) {
    FlValue* id_value = fl_value_get_list_value(ids_value, i);
    if (id_value == NULL ||
        fl_value_get_type(id_value) != FL_VALUE_TYPE_STRING) {
      continue;
    }
    const gchar* media_id = fl_value_get_string(id_value);
    g_autofree gchar* file_path = resolve_media_path(media_id);
    if (file_path == NULL ||
        !g_file_test(file_path, G_FILE_TEST_IS_REGULAR)) {
      continue;  // Omit failures.
    }
    g_autoptr(GError) error = NULL;
    g_autoptr(FlValue) map =
        build_thumbnail_map(file_path, width, height, &error);
    if (map == NULL) {
      continue;  // Omit failures.
    }
    fl_value_set(result, fl_value_new_string(media_id), map);
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// --- Original bytes ----------------------------------------------------

static FlMethodResponse* get_original_bytes(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  const gchar* media_id = get_string_arg(args, "mediaId");

  g_autofree gchar* file_path = resolve_media_path(media_id);
  if (file_path == NULL || !g_file_test(file_path, G_FILE_TEST_IS_REGULAR)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "NOT_FOUND", "Media not found", NULL));
  }

  g_autoptr(GFile) file = g_file_new_for_path(file_path);
  guint8* data = NULL;
  gsize length = 0;
  g_autoptr(GError) error = NULL;
  if (!g_file_load_contents(file, NULL, (gchar**)&data, &length, NULL,
                            &error)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "NOT_FOUND", "Media not found", NULL));
  }

  g_autoptr(FlValue) result = fl_value_new_uint8_list(data, length);
  g_free(data);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// --- Permissions & platform --------------------------------------------

static FlMethodResponse* get_permission_status(FlMethodCall* method_call) {
  (void)method_call;
  g_autoptr(FlValue) result = fl_value_new_string("granted");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* has_permission(FlMethodCall* method_call) {
  (void)method_call;
  g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* request_permission(FlMethodCall* method_call) {
  (void)method_call;
  g_autoptr(FlValue) result = fl_value_new_string("granted");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* get_platform_version(FlMethodCall* method_call) {
  (void)method_call;
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar* version =
      g_strdup_printf("Linux %s", uname_data.release);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Called when a method call is received from Flutter.
static void photo_gallery_pro_plugin_handle_method_call(
    PhotoGalleryProPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = NULL;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getAlbums") == 0) {
    response = get_albums(method_call);
  } else if (strcmp(method, "getAlbumThumbnail") == 0) {
    response = get_album_thumbnail(method_call);
  } else if (strcmp(method, "getThumbnail") == 0) {
    response = get_thumbnail(method_call);
  } else if (strcmp(method, "getThumbnailBatch") == 0) {
    response = get_thumbnail_batch(method_call);
  } else if (strcmp(method, "getOriginalBytes") == 0) {
    response = get_original_bytes(method_call);
  } else if (strcmp(method, "getMediaInAlbum") == 0) {
    response = get_media_in_album(method_call);
  } else if (strcmp(method, "getPermissionStatus") == 0) {
    response = get_permission_status(method_call);
  } else if (strcmp(method, "hasPermission") == 0) {
    response = has_permission(method_call);
  } else if (strcmp(method, "requestPermission") == 0) {
    response = request_permission(method_call);
  } else if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version(method_call);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, NULL);
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
      g_object_new(photo_gallery_pro_plugin_get_type(), NULL));

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
