#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // The screen guard (screen_guard.dart): keeps the window out of screen
  // captures while a sensitive screen is visible.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      guard_channel_;

  // The copy guard (copy_guard.dart): the clipboard sequence number the
  // app's last copy left (0 for none) and whether it was sensitive.
  DWORD our_sequence_ = 0;
  bool our_copy_is_sensitive_ = false;

  void RegisterGuardChannel();
  bool Copy(const std::string& text, bool sensitive);
  std::string ClearIfOurs();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
