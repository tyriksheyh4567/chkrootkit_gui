#include "my_application.h"

int main(int argc, char** argv) {
  // Prefer the compositor's Wayland connection in seatd-based sessions too.
  // Explicit user GDK_BACKEND always takes precedence. GUI never opens a seat.
  if (g_getenv("GDK_BACKEND") == nullptr &&
      g_getenv("WAYLAND_DISPLAY") != nullptr) {
    gdk_set_allowed_backends("wayland,x11");
  }
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
