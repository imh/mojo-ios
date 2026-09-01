#include <sys/stat.h>

int mojo_ios_injected_file_timestamp(const char *path) {
  struct stat file_status;
  return stat(path, &file_status);
}
