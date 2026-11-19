#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Windows app_links listens for WM_COPYDATA with dwData == WM_USER + 2.
// Forward only OAuth callbacks and only to an existing instance of this exe.
bool ForwardOAuthCallbackToRunningInstance(
    const std::vector<std::string>& arguments) {
  if (arguments.size() != 1 ||
      arguments.front().rfind("veredra://auth-callback/", 0) != 0 ||
      arguments.front().size() > 8192) {
    return false;
  }

  wchar_t currentPath[MAX_PATH] = {};
  if (::GetModuleFileNameW(nullptr, currentPath, MAX_PATH) == 0) {
    return false;
  }

  HWND candidate = nullptr;
  while ((candidate = ::FindWindowExW(nullptr, candidate,
                                     L"FLUTTER_RUNNER_WIN32_WINDOW",
                                     L"Veredra")) != nullptr) {
    DWORD processId = 0;
    ::GetWindowThreadProcessId(candidate, &processId);
    HANDLE process =
        ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, processId);
    if (process == nullptr) {
      continue;
    }

    wchar_t executablePath[MAX_PATH] = {};
    DWORD length = MAX_PATH;
    bool sameExecutable =
        ::QueryFullProcessImageNameW(process, 0, executablePath, &length) != 0 &&
        ::_wcsicmp(currentPath, executablePath) == 0;
    ::CloseHandle(process);
    if (!sameExecutable) {
      continue;  // Avoid sending PKCE codes to an older installed Veredra.
    }

    const std::string& link = arguments.front();
    COPYDATASTRUCT message = {};
    message.dwData = WM_USER + 2;
    message.cbData = static_cast<DWORD>(link.size() + 1);
    message.lpData = const_cast<char*>(link.c_str());
    DWORD_PTR ignoredResult = 0;
    if (::SendMessageTimeoutW(candidate, WM_COPYDATA, 0,
                              reinterpret_cast<LPARAM>(&message),
                              SMTO_ABORTIFHUNG, 3000, &ignoredResult) == 0) {
      return false;
    }
    ::ShowWindow(candidate, SW_RESTORE);
    ::SetForegroundWindow(candidate);
    return true;
  }
  return false;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  if (ForwardOAuthCallbackToRunningInstance(command_line_arguments)) {
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Veredra", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
