# Device-only native ARM64 build. No CPU translation or executable-memory entitlement.
set(PT_MOLTENVK_ROOT "" CACHE PATH "Extracted MoltenVK iOS release")
if(NOT PT_MOLTENVK_ROOT)
  message(FATAL_ERROR "Set PT_MOLTENVK_ROOT to the extracted official MoltenVK iOS distribution")
endif()
set(PT_IOS_MVK_FRAMEWORK "${PT_MOLTENVK_ROOT}/MoltenVK/dynamic/MoltenVK.xcframework/ios-arm64/MoltenVK.framework")
if(NOT EXISTS "${PT_IOS_MVK_FRAMEWORK}/MoltenVK")
  message(FATAL_ERROR "Missing device MoltenVK.framework at ${PT_IOS_MVK_FRAMEWORK}")
endif()
set_target_properties(pt PROPERTIES MACOSX_BUNDLE TRUE OUTPUT_NAME "PT"
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/ios/Info.plist.in"
  MACOSX_BUNDLE_GUI_IDENTIFIER "dev.local.pt.ios" MACOSX_BUNDLE_BUNDLE_NAME "P.T."
  MACOSX_BUNDLE_BUNDLE_VERSION "7" MACOSX_BUNDLE_SHORT_VERSION_STRING "0.1.6"
  XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO" XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2")
target_sources(pt PRIVATE ios/display.cpp ios/mobile_main.mm ios/document_folder.mm ios/touch_controls.mm ios/import_controller.mm ios/performance.mm)
set_source_files_properties(ios/mobile_main.mm ios/document_folder.mm ios/touch_controls.mm ios/import_controller.mm ios/performance.mm PROPERTIES COMPILE_FLAGS "-fobjc-arc")
target_link_libraries(pt PRIVATE "-framework UIKit" "-framework QuartzCore" "-framework UniformTypeIdentifiers" "-framework Foundation")
target_link_libraries(pt_engine PUBLIC whisper)
add_custom_command(TARGET pt POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${PT_IOS_MVK_FRAMEWORK}" "$<TARGET_FILE_DIR:pt>/Frameworks/MoltenVK.framework"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${PT_SPIRV_DIR}" "$<TARGET_FILE_DIR:pt>/shaders"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${PT_VOICE_DIR}" "$<TARGET_FILE_DIR:pt>/voice"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_SOURCE_DIR}/assets/lisa_date" "$<TARGET_FILE_DIR:pt>/lisa_date"
  VERBATIM)

file(GLOB PT_IOS_ICONS "${CMAKE_SOURCE_DIR}/ios/icons/*@*.png")
foreach(icon ${PT_IOS_ICONS})
  add_custom_command(TARGET pt POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy_if_different "${icon}" "$<TARGET_FILE_DIR:pt>" VERBATIM)
endforeach()

# Optional private build containing the user's own extracted archives.
set(PT_IOS_GAME_DIR "" CACHE PATH "Own extracted P.T. archive directory to bundle")
if(PT_IOS_GAME_DIR)
  foreach(name chunk1.psarc texture.qar pathid_list_ps4.bin)
    if(NOT EXISTS "${PT_IOS_GAME_DIR}/${name}")
      message(FATAL_ERROR "Missing game resource: ${PT_IOS_GAME_DIR}/${name}")
    endif()
    add_custom_command(TARGET pt POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:pt>/Game"
      COMMAND ${CMAKE_COMMAND} -E copy_if_different "${PT_IOS_GAME_DIR}/${name}" "$<TARGET_FILE_DIR:pt>/Game/${name}" VERBATIM)
  endforeach()
else()
  # Changing back to an engine-only build must not retain archives from a previous private build.
  add_custom_command(TARGET pt POST_BUILD COMMAND ${CMAKE_COMMAND} -E rm -rf "$<TARGET_FILE_DIR:pt>/Game" VERBATIM)
endif()

option(PT_METALFX "Build native Apple MetalFX temporal upscaling" ON)
if(PT_METALFX)
  target_sources(pt_engine PRIVATE src/engine/render/upscale/metalfx_backend.mm)
  target_compile_definitions(pt_engine PUBLIC PT_WITH_METALFX=1)
  target_link_libraries(pt_engine PUBLIC "-framework Metal" "-framework MetalFX" "-framework Foundation")
endif()
