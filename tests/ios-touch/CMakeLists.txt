cmake_minimum_required(VERSION 3.28)
project(TouchSmoke LANGUAGES C CXX OBJC OBJCXX)
set(CMAKE_CXX_STANDARD 20)
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
set(SDL_EXAMPLES OFF CACHE BOOL "" FORCE)
add_subdirectory("${SDL_SOURCE}" sdl)
add_executable(TouchSmoke MACOSX_BUNDLE main.mm ../../ios/document_folder.mm ../../ios/touch_controls.mm ../../ios/display.cpp)
target_compile_options(TouchSmoke PRIVATE -fobjc-arc)
target_link_libraries(TouchSmoke PRIVATE SDL3::SDL3-static "-framework UIKit" "-framework QuartzCore" "-framework Foundation")
set_target_properties(TouchSmoke PROPERTIES MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
  XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER dev.local.pt.touchsmoke
  XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "-" XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1")
