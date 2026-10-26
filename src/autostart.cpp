#include "autostart.h"

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <iostream>
#include <string>
#include <vector>

namespace
{
namespace fs = std::filesystem;

fs::path homeDirectory()
{
    if (const char *home = std::getenv("HOME"); home && *home) {
        return fs::path(home);
    }
    return fs::path("/tmp");
}

fs::path configDirectory()
{
    if (const char *xdg = std::getenv("XDG_CONFIG_HOME"); xdg && *xdg) {
        return fs::path(xdg);
    }
    return homeDirectory() / ".config";
}

fs::path autostartFile()
{
    return configDirectory() / "autostart" / "endfield-tray.desktop";
}

fs::path resolveExecutable(const char *argv0)
{
    std::error_code ec;
    const fs::path invoked = argv0 ? fs::path(argv0) : fs::path();
    if (invoked.has_parent_path()) {
        return fs::absolute(invoked, ec).lexically_normal();
    }

    if (const char *path = std::getenv("PATH"); path && *path) {
        std::string entries(path);
        size_t start = 0;
        while (start <= entries.size()) {
            const size_t end = entries.find(':', start);
            const std::string dir = entries.substr(start, end == std::string::npos ? std::string::npos : end - start);
            if (!dir.empty()) {
                const fs::path candidate = fs::path(dir) / invoked;
                if (fs::is_regular_file(candidate, ec)) {
                    return fs::absolute(candidate, ec).lexically_normal();
                }
            }
            if (end == std::string::npos) {
                break;
            }
            start = end + 1;
        }
    }

    const fs::path proc = fs::read_symlink("/proc/self/exe", ec);
    if (!ec && !proc.empty()) {
        return proc;
    }
    return fs::absolute(invoked, ec).lexically_normal();
}

std::string quoteExec(const fs::path &path)
{
    std::string value = path.string();
    if (value.find_first_of(" \t\"") == std::string::npos) {
        return value;
    }
    std::string quoted = "\"";
    for (const char ch : value) {
        if (ch == '"' || ch == '\\') {
            quoted += '\\';
        }
        quoted += ch;
    }
    quoted += '"';
    return quoted;
}

std::string readFile(const fs::path &path)
{
    std::ifstream file(path);
    return std::string(std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>());
}

std::string readEntryExec()
{
    const std::string text = readFile(autostartFile());
    const std::string prefix = "Exec=";
    const size_t start = text.find(prefix);
    if (start == std::string::npos) {
        return {};
    }
    const size_t begin = start + prefix.size();
    const size_t end = text.find('\n', begin);
    return text.substr(begin, end == std::string::npos ? std::string::npos : end - begin);
}

bool isEnabled()
{
    std::error_code ec;
    if (!fs::is_regular_file(autostartFile(), ec)) {
        return false;
    }
    const std::string text = readFile(autostartFile());
    return text.find("Hidden=true") == std::string::npos;
}

int writeEntry(const fs::path &exe)
{
    std::error_code ec;
    fs::create_directories(autostartFile().parent_path(), ec);
    if (ec) {
        std::cerr << "Could not create autostart directory: " << ec.message() << '\n';
        return 1;
    }

    std::ofstream file(autostartFile(), std::ios::trunc);
    if (!file) {
        std::cerr << "Could not write " << autostartFile() << '\n';
        return 1;
    }
    file << "[Desktop Entry]\n"
         << "Type=Application\n"
         << "Name=Endfield Tray\n"
         << "Name[zh_CN]=终末地悬浮任务栏\n"
         << "Comment=Compact Endfield-inspired floating taskbar for KDE Wayland\n"
         << "Exec=" << quoteExec(exe) << "\n"
         << "Icon=endfield-tray\n"
         << "Terminal=false\n"
         << "Categories=Utility;System;\n"
         << "StartupNotify=false\n"
         << "X-KDE-StartupNotify=false\n"
         << "StartupWMClass=endfield-tray\n";
    file.close();

    fs::permissions(autostartFile(),
                    fs::perms::owner_read | fs::perms::owner_write
                        | fs::perms::group_read | fs::perms::others_read,
                    fs::perm_options::replace, ec);
    return 0;
}

void printStatus(const fs::path &exe)
{
    const bool enabled = isEnabled();
    std::cout << "Autostart: " << (enabled ? "enabled" : "disabled") << '\n';
    std::cout << "Entry: " << autostartFile().string() << '\n';
    if (enabled) {
        const std::string entryExec = readEntryExec();
        std::cout << "Exec: " << (entryExec.empty() ? quoteExec(exe) : entryExec) << '\n';
    }
}
} // namespace

int handleAutostartCli(int argc, char *argv[])
{
    std::string action;
    bool requested = false;
    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--autostart") {
            requested = true;
            action = "status";
            if (i + 1 < argc && argv[i + 1][0] != '-') {
                action = argv[++i];
            }
            break;
        }
        if (arg.rfind("--autostart=", 0) == 0) {
            requested = true;
            action = arg.substr(std::string("--autostart=").size());
            break;
        }
    }

    if (!requested) {
        return -1;
    }

    const fs::path exe = resolveExecutable(argv[0]);
    if (action == "status" || action.empty()) {
        printStatus(exe);
        return 0;
    }
    if (action == "enable" || action == "on") {
        const int code = writeEntry(exe);
        if (code == 0) {
            std::cout << "Autostart: enabled\nEntry: " << autostartFile().string()
                      << "\nExec: " << quoteExec(exe) << '\n';
        }
        return code;
    }
    if (action == "disable" || action == "off") {
        std::error_code ec;
        fs::remove(autostartFile(), ec);
        if (ec) {
            std::cerr << "Could not remove " << autostartFile() << ": " << ec.message() << '\n';
            return 1;
        }
        std::cout << "Autostart: disabled\nEntry: " << autostartFile().string() << '\n';
        return 0;
    }

    std::cerr << "Unknown autostart action: " << action
              << "\nUsage: endfield-tray --autostart [status|enable|disable]\n";
    return 2;
}
