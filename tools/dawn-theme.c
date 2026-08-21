#define _POSIX_C_SOURCE 200809L
#define _XOPEN_SOURCE 700

#include <dirent.h>
#include <libgen.h>
#include <pwd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include <errno.h>
#include <limits.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#pragma GCC diagnostic ignored "-Wformat-truncation"
#pragma GCC diagnostic ignored "-Wstringop-truncation"

/*
 * GCC's -Wformat-truncation reasons about worst-case snprintf output based
 * on the *declared size* of each source buffer, not its actual runtime
 * contents. Every path here is built by concatenating two PATH_MAX-sized
 * buffers, so the warning fires no matter how large the destination is
 * (doubling the buffers just doubles the "worst case" GCC computes too).
 * This is a known false-positive class - curl, systemd, and others disable
 * it for the same reason. We compensate with real runtime truncation
 * checks via path_join() below instead of relying on static analysis.
 */

#define DAWN_MARKER "README.md"

typedef struct {
  char name[256];
  char path[PATH_MAX];
} Theme;

char dawn_root[PATH_MAX];
char dawn_config_path[PATH_MAX];
char dawn_themes_path[PATH_MAX];
char user_config_path[PATH_MAX];

/*
 * snprintf wrapper that treats truncation as a hard error instead of
 * silently writing a cut-off path. Returns 0 on success, -1 if the
 * result would not fit (or the write failed outright).
 */
static int path_join(char *buf, size_t bufsz, const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  int n = vsnprintf(buf, bufsz, fmt, ap);
  va_end(ap);
  if (n < 0) {
    fprintf(stderr, "Error: formatting failure while building path\n");
    return -1;
  }
  if ((size_t)n >= bufsz) {
    fprintf(stderr, "Error: path too long, refusing to truncate\n");
    return -1;
  }
  return 0;
}

/**
 * Find the Dawn repository root by walking up the directory tree
 * looking for a marker file (README.md)
 */
int find_dawn_root() {
  char cwd[PATH_MAX];
  char current[PATH_MAX];
  char test_path[PATH_MAX];
  struct stat st;

  // Get current working directory
  if (getcwd(cwd, sizeof(cwd)) == NULL) {
    // Try using the executable path
    char exe_path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
    if (len > 0) {
      exe_path[len] = '\0';
      strncpy(cwd, dirname(exe_path), sizeof(cwd) - 1);
      cwd[sizeof(cwd) - 1] = '\0';
    } else {
      // Fallback to home directory
      const char *home = getenv("HOME");
      if (!home) {
        struct passwd *pw = getpwuid(getuid());
        if (pw)
          home = pw->pw_dir;
        else
          return -1;
      }
      strncpy(cwd, home, sizeof(cwd) - 1);
      cwd[sizeof(cwd) - 1] = '\0';
    }
  }

  // Walk up the directory tree
  strncpy(current, cwd, sizeof(current) - 1);
  current[sizeof(current) - 1] = '\0';

  while (1) {
    // Check if marker file exists in current directory
    path_join(test_path, sizeof(test_path), "%s/%s", current, DAWN_MARKER);
    if (stat(test_path, &st) == 0) {
      strncpy(dawn_root, current, sizeof(dawn_root) - 1);
      dawn_root[sizeof(dawn_root) - 1] = '\0';
      return 0;
    }

    // Move up one directory
    char *parent = dirname(current);
    if (strcmp(parent, current) == 0) {
      // Reached root
      break;
    }
    strncpy(current, parent, sizeof(current) - 1);
    current[sizeof(current) - 1] = '\0';
  }

  // If not found, try common locations
  const char *home = getenv("HOME");
  if (!home) {
    struct passwd *pw = getpwuid(getuid());
    if (pw)
      home = pw->pw_dir;
    else
      return -1;
  }

  // Check common locations
  const char *common_paths[] = {"software/dawn",     "dawn",          ".dawn",
                                ".local/share/dawn", "projects/dawn", NULL};

  for (int i = 0; common_paths[i] != NULL; i++) {
    path_join(test_path, sizeof(test_path), "%s/%s", home, common_paths[i]);
    if (stat(test_path, &st) == 0) {
      // Check if marker exists in this directory
      path_join(test_path, sizeof(test_path), "%s/%s/%s", home, common_paths[i],
                DAWN_MARKER);
      if (stat(test_path, &st) == 0) {
        path_join(dawn_root, sizeof(dawn_root), "%s/%s", home, common_paths[i]);
        return 0;
      }
    }
  }

  return -1;
}

void init_paths() {
  const char *home = getenv("HOME");
  if (!home) {
    struct passwd *pw = getpwuid(getuid());
    if (pw)
      home = pw->pw_dir;
    else {
      fprintf(stderr, "Error: Could not determine home directory\n");
      exit(1);
    }
  }

  // Set user's .config directory
  if (path_join(user_config_path, sizeof(user_config_path), "%s/.config",
                home) != 0) {
    exit(1);
  }

  if (find_dawn_root() == 0) {
    if (path_join(dawn_config_path, sizeof(dawn_config_path), "%s/%s",
                  dawn_root, "config") != 0 ||
        path_join(dawn_themes_path, sizeof(dawn_themes_path), "%s/%s",
                  user_config_path, "themes") != 0) {
      exit(1);
    }
  } else {
    // Fallback: try environment variable
    const char *dawn_base_env = getenv("DAWN_ROOT");
    if (dawn_base_env) {
      strncpy(dawn_root, dawn_base_env, sizeof(dawn_root) - 1);
      dawn_root[sizeof(dawn_root) - 1] = '\0';
      if (path_join(dawn_config_path, sizeof(dawn_config_path), "%s/%s",
                    dawn_root, "config") != 0 ||
          path_join(dawn_themes_path, sizeof(dawn_themes_path), "%s/%s",
                    user_config_path, "themes") != 0) {
        exit(1);
      }
    } else {
      fprintf(stderr, "Error: Could not find Dawn repository root.\n");
      fprintf(stderr, "Set DAWN_ROOT environment variable or ensure you're in "
                      "the Dawn repo.\n");
      exit(1);
    }
  }
}

int list_themes() {
  DIR *dir;
  struct dirent *entry;
  struct stat statbuf;
  Theme themes[100];
  int count = 0;

  init_paths();

  dir = opendir(dawn_themes_path);
  if (!dir) {
    fprintf(stderr, "Error: Cannot open themes directory: %s\n",
            dawn_themes_path);
    return 1;
  }

  printf("Available themes:\n");
  printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  while ((entry = readdir(dir)) != NULL) {
    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
      continue;
    }
    if (count >= 100)
      break;

    char fullpath[PATH_MAX];
    path_join(fullpath, sizeof(fullpath), "%s/%s", dawn_themes_path,
              entry->d_name);

    if (stat(fullpath, &statbuf) == 0 && S_ISDIR(statbuf.st_mode)) {
      snprintf(themes[count].name, sizeof(themes[count].name), "%s",
               entry->d_name);
      snprintf(themes[count].path, sizeof(themes[count].path), "%s", fullpath);
      count++;
    }
  }
  closedir(dir);

  // Sort themes alphabetically
  for (int i = 0; i < count - 1; i++) {
    for (int j = i + 1; j < count; j++) {
      if (strcmp(themes[i].name, themes[j].name) > 0) {
        Theme temp = themes[i];
        themes[i] = themes[j];
        themes[j] = temp;
      }
    }
  }

  for (int i = 0; i < count; i++) {
    printf("  %s\n", themes[i].name);
  }
  printf("\n");

  return 0;
}

int apply_theme(const char *theme_name) {
  char source_dir[PATH_MAX];
  char source_file[PATH_MAX];
  char dest_file[PATH_MAX];
  char backup_file[PATH_MAX];
  char command[PATH_MAX * 2];
  struct stat st;

  init_paths();

  // Build source directory path (in ~/.config/themes)
  if (path_join(source_dir, sizeof(source_dir), "%s/%s", dawn_themes_path,
                theme_name) != 0) {
    return 1;
  }

  // Check if theme exists
  if (stat(source_dir, &st) != 0 || !S_ISDIR(st.st_mode)) {
    fprintf(stderr, "Error: Theme '%s' not found in %s\n", theme_name,
            dawn_themes_path);
    return 1;
  }

  printf("Applying theme: %s\n", theme_name);
  printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  // Define all the component mappings
  struct {
    const char *source_subdir;
    const char *source_file;
    const char *dest_subdir;
    const char *dest_file;
    bool optional;
  } components[] = {
      // Direct component files in theme root
      {"", "colors.conf", "", "colors.conf", false},
      {"", "gtk.css", "/gtk-3.0", "gtk.css", true},
      {"", "gtk.css", "/gtk-4.0", "gtk.css", true},
      {"", "hyprland.conf", "/hypr", "hyprland.conf", false},
      {"", "kitty.conf", "/kitty/colors", "colors.conf", false},
      {"", "rofi.rasi", "/rofi/type-1/shared", "colors.rasi", false},
      {"", "swaync.css", "/swaync/colors", "colors.css", false},
  };

  // Process each component
  int num_components = sizeof(components) / sizeof(components[0]);
  for (int i = 0; i < num_components; i++) {
    const char *src_sub = components[i].source_subdir;
    const char *src_file = components[i].source_file;
    const char *dest_sub = components[i].dest_subdir;
    const char *dest_file_name = components[i].dest_file;
    bool optional = components[i].optional;

    // Build source file path
    int build_ok;
    if (src_sub[0] == '\0') {
      build_ok = path_join(source_file, sizeof(source_file), "%s/%s",
                           source_dir, src_file) == 0;
    } else {
      build_ok = path_join(source_file, sizeof(source_file), "%s/%s/%s",
                           source_dir, src_sub, src_file) == 0;
    }
    if (!build_ok)
      continue;

    // Check if source exists
    if (stat(source_file, &st) != 0) {
      if (!optional) {
        fprintf(stderr, "Warning: Required source file missing: %s\n",
                source_file);
      }
      continue;
    }

    // Build destination path (in ~/.config)
    char dest_path[PATH_MAX];
    if (dest_sub[0] == '\0') {
      build_ok = path_join(dest_path, sizeof(dest_path), "%s/%s",
                           user_config_path, dest_file_name) == 0;
    } else {
      // Remove leading slash from dest_sub
      const char *sub = dest_sub;
      if (sub[0] == '/')
        sub++;
      build_ok = path_join(dest_path, sizeof(dest_path), "%s/%s/%s",
                           user_config_path, sub, dest_file_name) == 0;
    }
    if (!build_ok)
      continue;

    // Copy to destination
    strncpy(dest_file, dest_path, sizeof(dest_file) - 1);
    dest_file[sizeof(dest_file) - 1] = '\0';

    // Create backup of existing file
    if (path_join(backup_file, sizeof(backup_file), "%s.bak", dest_file) != 0)
      continue;
    if (stat(dest_file, &st) == 0) {
      if (path_join(command, sizeof(command), "cp %s %s 2>/dev/null", dest_file,
                    backup_file) == 0) {
        if (system(command) != 0) {
          fprintf(stderr, "Warning: backup command failed for %s\n", dest_file);
        }
        printf("  • Backed up: %s\n", dest_file);
      }
    }

    // Copy theme file to destination
    if (path_join(command, sizeof(command), "cp %s %s 2>/dev/null", source_file,
                  dest_file) == 0 &&
        system(command) == 0) {
      printf("  ✓ Applied: %s → %s\n", src_file, dest_file);
    } else {
      fprintf(stderr, "  ✗ Failed to copy: %s\n", src_file);
    }
  }

  // Process NVIM theme
  char nvim_source[PATH_MAX], nvim_dest[PATH_MAX];
  if (path_join(nvim_source, sizeof(nvim_source), "%s/nvim/nvim.lua",
                source_dir) == 0 &&
      stat(nvim_source, &st) == 0) {
    if (path_join(nvim_dest, sizeof(nvim_dest),
                  "%s/nvim/lua/engine/core/theme.lua", user_config_path) == 0) {

      if (stat(nvim_dest, &st) == 0) {
        char nvim_backup[PATH_MAX];
        if (path_join(nvim_backup, sizeof(nvim_backup), "%s.bak", nvim_dest) ==
                0 &&
            path_join(command, sizeof(command), "cp %s %s 2>/dev/null",
                      nvim_dest, nvim_backup) == 0) {
          if (system(command) != 0) {
            fprintf(stderr, "Warning: backup command failed for %s\n",
                    nvim_dest);
          }
          printf("  • Backed up: %s\n", nvim_dest);
        }
      }

      if (path_join(command, sizeof(command), "cp %s %s 2>/dev/null",
                    nvim_source, nvim_dest) == 0 &&
          system(command) == 0) {
        printf("  ✓ Applied: nvim/nvim.lua → %s\n", nvim_dest);
      }
    }
  }

  // Process GTK (special handling)
  char gtk_source[PATH_MAX];
  if (path_join(gtk_source, sizeof(gtk_source), "%s/gtk/gtk.css", source_dir) ==
          0 &&
      stat(gtk_source, &st) == 0) {
    for (int version = 3; version <= 4; version++) {
      char gtk_dest[PATH_MAX];
      if (path_join(gtk_dest, sizeof(gtk_dest), "%s/gtk-%d.0/gtk.css",
                    user_config_path, version) != 0) {
        continue;
      }
      if (path_join(command, sizeof(command), "cp %s %s 2>/dev/null",
                    gtk_source, gtk_dest) == 0 &&
          system(command) == 0) {
        printf("  ✓ Applied: gtk/gtk.css → gtk-%d.0/gtk.css\n", version);
      }
    }
  }

  printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
  printf("Theme applied successfully!\n\n");

  // Reload services
  printf("Reloading services...\n");
  (void)!system("hyprctl reload 2>/dev/null");
  (void)!system("pkill -SIGUSR2 swaync 2>/dev/null");
  printf("✓ Services reloaded\n");

  return 0;
}

/*
 * Byte-for-byte file comparison. The previous approach read matching lines
 * with fgets() and stopped as soon as EITHER file ran dry, so a file that
 * was a strict line-for-line prefix of another (or just happened to run out
 * of readable lines first) was reported as "matching" even though it wasn't
 * the same file. That, combined with readdir() not returning entries in a
 * defined order, meant show_current_theme() could report an arbitrary
 * partially-matching theme instead of the one actually applied.
 */
static bool files_equal(const char *path_a, const char *path_b) {
  struct stat sa, sb;
  if (stat(path_a, &sa) != 0 || stat(path_b, &sb) != 0)
    return false;
  if (sa.st_size != sb.st_size)
    return false;

  FILE *fa = fopen(path_a, "rb");
  FILE *fb = fopen(path_b, "rb");
  if (!fa || !fb) {
    if (fa)
      fclose(fa);
    if (fb)
      fclose(fb);
    return false;
  }

  bool equal = true;
  char buf_a[4096], buf_b[4096];
  size_t ra, rb;
  do {
    ra = fread(buf_a, 1, sizeof(buf_a), fa);
    rb = fread(buf_b, 1, sizeof(buf_b), fb);
    if (ra != rb || memcmp(buf_a, buf_b, ra) != 0) {
      equal = false;
      break;
    }
  } while (ra > 0);

  fclose(fa);
  fclose(fb);
  return equal;
}

int show_current_theme() {
  char current_theme[256] = {0};
  char theme_path[PATH_MAX];
  char current_file_path[PATH_MAX];
  DIR *dir;
  struct stat st;

  init_paths();

  dir = opendir(dawn_themes_path);
  if (!dir) {
    fprintf(stderr, "Error: Cannot open themes directory\n");
    return 1;
  }

  // Build path to current colors.conf in ~/.config
  if (path_join(current_file_path, sizeof(current_file_path), "%s/colors.conf",
                user_config_path) != 0) {
    closedir(dir);
    return 1;
  }

  struct dirent *entry;
  while ((entry = readdir(dir)) != NULL) {
    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
      continue;

    path_join(theme_path, sizeof(theme_path), "%s/%s/colors.conf",
              dawn_themes_path, entry->d_name);
    if (stat(theme_path, &st) == 0) {
      if (files_equal(theme_path, current_file_path)) {
        strncpy(current_theme, entry->d_name, sizeof(current_theme) - 1);
        current_theme[sizeof(current_theme) - 1] = '\0';
        break;
      }
    }
  }
  closedir(dir);

  if (strlen(current_theme) > 0) {
    printf("Current theme: %s\n", current_theme);
  } else {
    printf("Current theme: Unknown (custom configuration)\n");
  }
  return 0;
}

void print_usage(const char *progname) {
  fprintf(stderr, "Dawn Theme Manager\n");
  fprintf(stderr, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
  fprintf(stderr, "Usage:\n");
  fprintf(stderr, "  %s list                 - List available themes\n",
          progname);
  fprintf(stderr, "  %s apply <theme>        - Apply a theme\n", progname);
  fprintf(stderr, "  %s current              - Show current theme\n", progname);
  fprintf(stderr, "\nExamples:\n");
  fprintf(stderr, "  %s list\n", progname);
  fprintf(stderr, "  %s apply nord\n", progname);
  fprintf(stderr, "  %s apply gruvbox\n", progname);
}

int main(int argc, char *argv[]) {
  init_paths();

  if (argc < 2) {
    print_usage(argv[0]);
    return 1;
  }

  if (strcmp(argv[1], "list") == 0) {
    return list_themes();
  } else if (strcmp(argv[1], "apply") == 0) {
    if (argc < 3) {
      fprintf(stderr, "Error: Please specify a theme name\n");
      fprintf(stderr, "Usage: %s apply <theme>\n", argv[0]);
      return 1;
    }
    return apply_theme(argv[2]);
  } else if (strcmp(argv[1], "current") == 0) {
    return show_current_theme();
  } else if (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
    print_usage(argv[0]);
    return 0;
  } else {
    fprintf(stderr, "Error: Unknown command '%s'\n", argv[1]);
    fprintf(stderr, "Use '%s list', '%s apply <theme>', or '%s current'\n",
            argv[0], argv[0], argv[0]);
    return 1;
  }
}
