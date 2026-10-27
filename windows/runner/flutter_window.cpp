#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <cstring>
#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

// Windows 10 2004+; older SDK headers do not name it.
#ifndef WDA_EXCLUDEFROMCAPTURE
#define WDA_EXCLUDEFROMCAPTURE 0x00000011
#endif

namespace {

// Puts a DWORD under the registered clipboard format |name|; the clipboard
// must be open and owned. The clipboard owns the memory once set.
void SetClipboardDword(const wchar_t* name, DWORD value) {
  const UINT format = RegisterClipboardFormatW(name);
  if (format == 0) return;
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, sizeof(DWORD));
  if (memory == nullptr) return;
  void* locked = GlobalLock(memory);
  if (locked == nullptr) {
    GlobalFree(memory);
    return;
  }
  *static_cast<DWORD*>(locked) = value;
  GlobalUnlock(memory);
  if (SetClipboardData(format, memory) == nullptr) GlobalFree(memory);
}

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                         utf8.data(),
                                         static_cast<int>(utf8.size()),
                                         nullptr, 0);
  if (length <= 0) return std::wstring();
  std::wstring utf16(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                      static_cast<int>(utf8.size()), utf16.data(), length);
  return utf16;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterGuardChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  return true;
}

void FlutterWindow::OnDestroy() {
  // A sensitive copy does not outlive the app's window.
  if (our_copy_is_sensitive_) ClearIfOurs();
  guard_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

// `setSecure` excludes the window from screenshots and screen recordings
// (it shows as black or is left out); before Windows 10 2004 the window still
// shows on screen but captures come out black where the system supports it.
//
// `copy` writes the text itself (security review 2026-10-26). A sensitive
// copy (a safe password) also carries the formats Windows reads to keep it
// out of clipboard history (Win+V), the cloud clipboard and clipboard
// monitors: `ExcludeClipboardContentFromMonitorProcessing`,
// `CanIncludeInClipboardHistory` = 0 and `CanUploadToCloudClipboard` = 0.
// `clearIfOurs` empties the clipboard only while its sequence number is still
// the one this copy left, so another app's text is never read.
bool FlutterWindow::Copy(const std::string& text, bool sensitive) {
  const std::wstring wide = Utf16FromUtf8(text);
  if (wide.empty() && !text.empty()) return false;
  if (!OpenClipboard(GetHandle())) return false;
  EmptyClipboard();
  const size_t bytes = (wide.size() + 1) * sizeof(wchar_t);
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, bytes);
  bool written = false;
  if (memory != nullptr) {
    void* locked = GlobalLock(memory);
    if (locked != nullptr) {
      memcpy(locked, wide.c_str(), bytes);
      GlobalUnlock(memory);
      written = SetClipboardData(CF_UNICODETEXT, memory) != nullptr;
    }
    if (!written) GlobalFree(memory);
  }
  if (written && sensitive) {
    SetClipboardDword(L"ExcludeClipboardContentFromMonitorProcessing", 0);
    SetClipboardDword(L"CanIncludeInClipboardHistory", 0);
    SetClipboardDword(L"CanUploadToCloudClipboard", 0);
  }
  CloseClipboard();
  if (!written) return false;
  our_sequence_ = GetClipboardSequenceNumber();
  our_copy_is_sensitive_ = sensitive;
  return true;
}

std::string FlutterWindow::ClearIfOurs() {
  if (our_sequence_ == 0) return "notOurs";
  const DWORD ours = our_sequence_;
  our_sequence_ = 0;
  our_copy_is_sensitive_ = false;
  if (GetClipboardSequenceNumber() != ours) return "notOurs";
  if (!OpenClipboard(GetHandle())) return "unavailable";
  EmptyClipboard();
  CloseClipboard();
  return "cleared";
}

void FlutterWindow::RegisterGuardChannel() {
  guard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.fuzzzycore.ink/guard",
          &flutter::StandardMethodCodec::GetInstance());
  guard_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "copy") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments == nullptr) {
            result->Error("badArguments", "text is missing");
            return;
          }
          const auto text_entry =
              arguments->find(flutter::EncodableValue("text"));
          const auto sensitive_entry =
              arguments->find(flutter::EncodableValue("sensitive"));
          const std::string* text =
              text_entry == arguments->end()
                  ? nullptr
                  : std::get_if<std::string>(&text_entry->second);
          if (text == nullptr) {
            result->Error("badArguments", "text is missing");
            return;
          }
          const bool* sensitive =
              sensitive_entry == arguments->end()
                  ? nullptr
                  : std::get_if<bool>(&sensitive_entry->second);
          result->Success(flutter::EncodableValue(
              Copy(*text, sensitive != nullptr && *sensitive)));
          return;
        }
        if (call.method_name() == "clearIfOurs") {
          result->Success(flutter::EncodableValue(ClearIfOurs()));
          return;
        }
        if (call.method_name() != "setSecure") {
          result->NotImplemented();
          return;
        }
        const bool* requested = std::get_if<bool>(call.arguments());
        const bool secure = requested != nullptr && *requested;
        HWND window = GetHandle();
        BOOL applied = SetWindowDisplayAffinity(
            window, secure ? WDA_EXCLUDEFROMCAPTURE : WDA_NONE);
        if (!applied && secure) {
          applied = SetWindowDisplayAffinity(window, WDA_MONITOR);
        }
        result->Success(flutter::EncodableValue(applied != FALSE));
      });
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
