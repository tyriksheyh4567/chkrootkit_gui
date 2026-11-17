#include <cerrno>
#include <csignal>
#include <cstring>
#include <fcntl.h>
#include <iostream>
#include <map>
#include <cstdlib>
#include <pwd.h>
#include <sys/stat.h>
#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

namespace {

constexpr char kPath[] =
    "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";

struct CommandResult {
  int exit_code;
  std::string output;
};

std::string JsonEscape(const std::string& value) {
  std::string result;
  result.reserve(value.size() + 16);
  for (const char character : value) {
    switch (character) {
      case '"':
        result += "\\\"";
        break;
      case '\\':
        result += "\\\\";
        break;
      case '\n':
        result += "\\n";
        break;
      case '\r':
        result += "\\r";
        break;
      case '\t':
        result += "\\t";
        break;
      default:
        if (static_cast<unsigned char>(character) < 0x20) {
          result += ' ';
        } else {
          result += character;
        }
    }
  }
  return result;
}

bool ReadJsonString(const std::string& json, const std::string& key,
                    std::string* value) {
  const std::string needle = "\"" + key + "\"";
  const std::size_t key_position = json.find(needle);
  if (key_position == std::string::npos) return false;
  const std::size_t colon = json.find(':', key_position + needle.size());
  if (colon == std::string::npos) return false;
  const std::size_t opening_quote = json.find('"', colon + 1);
  if (opening_quote == std::string::npos) return false;

  std::string parsed;
  bool escaped = false;
  for (std::size_t index = opening_quote + 1; index < json.size(); ++index) {
    const char character = json[index];
    if (escaped) {
      switch (character) {
        case '"':
        case '\\':
        case '/':
          parsed += character;
          break;
        case 'n':
          parsed += '\n';
          break;
        case 'r':
          parsed += '\r';
          break;
        case 't':
          parsed += '\t';
          break;
        default:
          return false;
      }
      escaped = false;
      continue;
    }
    if (character == '\\') {
      escaped = true;
    } else if (character == '"') {
      *value = parsed;
      return true;
    } else {
      parsed += character;
    }
  }
  return false;
}

bool ReadJsonNumber(const std::string& json, const std::string& key,
                    std::string* value) {
  const std::string needle = "\"" + key + "\"";
  const std::size_t key_position = json.find(needle);
  if (key_position == std::string::npos) return false;
  const std::size_t colon = json.find(':', key_position + needle.size());
  if (colon == std::string::npos) return false;
  std::size_t start = colon + 1;
  while (start < json.size() && json[start] == ' ') ++start;
  std::size_t end = start;
  while (end < json.size() && json[end] >= '0' && json[end] <= '9') ++end;
  if (end == start) return false;
  *value = json.substr(start, end - start);
  return true;
}

bool IsAllowedTool(const std::string& tool, std::vector<std::string>* argv) {
  if (tool == "chkrootkit") {
    *argv = {"chkrootkit"};
    return true;
  }
  if (tool == "rkhunter") {
    *argv = {"rkhunter", "--check", "--skip-keypress",
             "--report-warnings-only", "--nocolors"};
    return true;
  }
  if (tool == "unhide") {
    *argv = {"unhide", "-u", "-H", "quick"};
    return true;
  }
  if (tool == "lynis") {
    *argv = {"lynis", "audit", "system", "--quick", "--no-colors"};
    return true;
  }
  return false;
}

bool IsAllowedInstall(const std::string& manager, const std::string& package,
                      std::vector<std::string>* argv) {
  static const std::map<std::string, bool> packages = {
      {"chkrootkit", true}, {"rkhunter", true},
      {"unhide", true},     {"lynis", true},
  };
  if (packages.find(package) == packages.end()) return false;
  if (manager == "apt-get" || manager == "dnf") {
    *argv = {manager, "install", "-y", package};
    return true;
  }
  if (manager == "pacman") {
    *argv = {manager, "-S", "--noconfirm", package};
    return true;
  }
  if (manager == "zypper") {
    *argv = {manager, "--non-interactive", "install", package};
    return true;
  }
  return false;
}

std::string CanonicalPath(const std::string& path) {
  char* resolved = realpath(path.c_str(), nullptr);
  if (resolved == nullptr) return "";
  const std::string result(resolved);
  free(resolved);
  return result;
}

std::string CallerHome() {
  uid_t uid = getuid();
  if (const char* value = getenv("PKEXEC_UID")) {
    char* end = nullptr;
    const unsigned long parsed = strtoul(value, &end, 10);
    if (end == value || *end != '\0') return "";
    uid = static_cast<uid_t>(parsed);
  }
  const passwd* entry = getpwuid(uid);
  return entry == nullptr ? "" : entry->pw_dir;
}

bool AllowedScanPath(const std::string& tool, const std::string& path,
                     const std::string& home) {
  for (const std::string directory : {"/usr/local/sbin", "/usr/local/bin",
       "/usr/sbin", "/usr/bin", "/sbin", "/bin"}) {
    if (path == directory + "/" + tool) return true;
  }
  return !home.empty() && path == home + "/.local/bin/" + tool;
}

bool PrepareScan(const std::string& tool, const std::string& requested_executable,
                 const std::string& requested_directory,
                 std::vector<std::string>* command, std::string* directory,
                 std::string* error, const std::string& caller_home = CallerHome()) {
  if (!IsAllowedTool(tool, command)) { *error = "unknown scanner"; return false; }
  std::string executable = requested_executable;
  if (executable.empty()) {
    for (const std::string prefix : {"/usr/local/sbin", "/usr/local/bin", "/usr/sbin", "/usr/bin", "/sbin", "/bin"}) {
      const std::string candidate = prefix + "/" + tool;
      if (access(candidate.c_str(), X_OK) == 0) { executable = candidate; break; }
    }
  }
  if (!AllowedScanPath(tool, executable, caller_home) || executable.find('\0') != std::string::npos) {
    *error = "scanner path is not an allowed system or caller ~/.local/bin path"; return false;
  }
  const std::string canonical = CanonicalPath(executable);
  struct stat executable_stat {};
  if (canonical.empty() || stat(canonical.c_str(), &executable_stat) != 0 ||
      !S_ISREG(executable_stat.st_mode) || access(canonical.c_str(), X_OK) != 0) {
    *error = "scanner is missing or not executable"; return false;
  }
  (*command)[0] = canonical;
  if (requested_directory.empty()) {
    *directory = canonical.substr(0, canonical.find_last_of('/'));
  } else {
    if (requested_directory[0] != '/' || requested_directory.find('\0') != std::string::npos) {
      *error = "working directory must be an absolute path"; return false;
    }
    *directory = CanonicalPath(requested_directory);
  }
  struct stat directory_stat {};
  if (directory->empty() || stat(directory->c_str(), &directory_stat) != 0 || !S_ISDIR(directory_stat.st_mode)) {
    *error = "working directory does not exist or is not a directory"; return false;
  }
  return true;
}

bool AddScanRoot(const std::string& tool, const std::string& root,
                 std::vector<std::string>* command, std::string* error) {
  if (root.empty() || root == "/") return true;
  if (tool != "chkrootkit") { *error = "scanner only supports the running system"; return false; }
  if (root[0] != '/' || root.find('\0') != std::string::npos) { *error = "scan root must be absolute"; return false; }
  const std::string canonical = CanonicalPath(root);
  struct stat info {};
  if (canonical.empty() || stat(canonical.c_str(), &info) != 0 || !S_ISDIR(info.st_mode)) { *error = "scan root is not a directory"; return false; }
  command->push_back("-r"); command->push_back(canonical);
  return true;
}

CommandResult RunCommand(const std::vector<std::string>& arguments,
                         const std::string& directory = "/") {
  int output_pipe[2];
  if (pipe(output_pipe) != 0) {
    return {127, std::strerror(errno)};
  }

  const pid_t child = fork();
  if (child < 0) {
    close(output_pipe[0]);
    close(output_pipe[1]);
    return {127, std::strerror(errno)};
  }
  if (child == 0) {
    dup2(output_pipe[1], STDOUT_FILENO);
    dup2(output_pipe[1], STDERR_FILENO);
    close(output_pipe[0]);
    close(output_pipe[1]);
    const int null_input = open("/dev/null", O_RDONLY);
    if (null_input < 0 || dup2(null_input, STDIN_FILENO) < 0) _exit(127);
    close(null_input);
    if (chdir(directory.c_str()) != 0) {
      const std::string error = std::string("chdir failed: ") + std::strerror(errno) + "\n";
      (void)write(STDERR_FILENO, error.c_str(), error.size());
      _exit(127);
    }
    setenv("PATH", kPath, 1);
    setenv("LANG", "C.UTF-8", 1);
    setenv("LC_ALL", "C.UTF-8", 1);

    std::vector<char*> argv;
    argv.reserve(arguments.size() + 1);
    for (const std::string& argument : arguments) {
      argv.push_back(const_cast<char*>(argument.c_str()));
    }
    argv.push_back(nullptr);
    execvp(argv[0], argv.data());
    const std::string error = std::string("exec failed: ") + std::strerror(errno) + "\n";
    (void)write(STDERR_FILENO, error.c_str(), error.size());
    _exit(127);
  }

  close(output_pipe[1]);
  std::string output;
  char buffer[4096];
  ssize_t bytes_read;
  while ((bytes_read = read(output_pipe[0], buffer, sizeof(buffer))) > 0) {
    output.append(buffer, static_cast<std::size_t>(bytes_read));
  }
  close(output_pipe[0]);

  int status = 0;
  if (waitpid(child, &status, 0) < 0) {
    return {127, output + std::strerror(errno)};
  }
  if (WIFEXITED(status)) return {WEXITSTATUS(status), output};
  if (WIFSIGNALED(status)) return {128 + WTERMSIG(status), output};
  return {127, output};
}

void WriteError(const std::string& id, const std::string& error) {
  std::cout << "{\"id\":" << (id.empty() ? "null" : id)
            << ",\"error\":\""
            << JsonEscape(error) << "\"}" << std::endl;
}

void HandleRequest(const std::string& line) {
  std::string id;
  std::string operation;
  if (!ReadJsonNumber(line, "id", &id) ||
      !ReadJsonString(line, "op", &operation)) {
    WriteError(id, "invalid request");
    return;
  }

  std::vector<std::string> command;
  std::string directory = "/";
  if (operation == "scan") {
    std::string tool, executable, requested_directory, error;
    if (!ReadJsonString(line, "tool", &tool)) { WriteError(id, "unknown scanner"); return; }
    if (line.find("\"executable\"") != std::string::npos && !ReadJsonString(line, "executable", &executable)) {
      WriteError(id, "invalid executable path"); return;
    }
    if (line.find("\"workingDirectory\"") != std::string::npos && !ReadJsonString(line, "workingDirectory", &requested_directory)) {
      WriteError(id, "invalid working directory"); return;
    }
    std::string scan_root = "/";
    if (line.find("\"scanRoot\"") != std::string::npos && !ReadJsonString(line, "scanRoot", &scan_root)) { WriteError(id, "invalid scan root"); return; }
    if (!PrepareScan(tool, executable, requested_directory, &command, &directory, &error)) {
      WriteError(id, error); return;
    }
    if (!AddScanRoot(tool, scan_root, &command, &error)) { WriteError(id, error); return; }
  } else if (operation == "install") {
    std::string manager;
    std::string package;
    if (!ReadJsonString(line, "manager", &manager) ||
        !ReadJsonString(line, "package", &package) ||
        !IsAllowedInstall(manager, package, &command)) {
      WriteError(id, "unsupported package installation");
      return;
    }
  } else {
    WriteError(id, "unknown operation");
    return;
  }

  const CommandResult result = RunCommand(command, directory);
  std::cout << "{\"id\":" << id
            << ",\"result\":{\"exitCode\":" << result.exit_code
            << ",\"stdout\":\"" << JsonEscape(result.output)
            << "\",\"stderr\":\"\",\"workingDirectory\":\"" << JsonEscape(directory)
            << "\",\"executable\":\"" << JsonEscape(command[0]) << "\"}}" << std::endl;
}

}  // namespace

int main() {
  std::ios::sync_with_stdio(false);
  std::cout << "{\"ready\":true}" << std::endl;

  std::string line;
  while (std::getline(std::cin, line)) {
    if (!line.empty()) HandleRequest(line);
  }
  return 0;
}
