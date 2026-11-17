add_executable(rootkit_guard_service rootkit_service.cc)

target_compile_features(rootkit_guard_service PRIVATE cxx_std_17)
target_compile_options(rootkit_guard_service PRIVATE -Wall -Wextra -Werror)

# Keep the helper next to the runner for `flutter run`; install rules below put
# the same binary next to the release bundle executable.
set_target_properties(rootkit_guard_service PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/intermediates_do_not_run")

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  install(TARGETS rootkit_guard_service RUNTIME DESTINATION bin)
endif()
cmake_minimum_required(VERSION 3.13)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  project(rootkit_guard_service LANGUAGES CXX)
endif()

