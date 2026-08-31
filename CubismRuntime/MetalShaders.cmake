set(shader_root "${CUBISM_SDK_ROOT}/Framework/src/Rendering/Metal/Shaders")
set(shader_air_root "${CUBISM_BUILD_ROOT}/shaders")
set(shader_library_root "${CUBISM_BUILD_ROOT}/FrameworkMetallibs")
file(MAKE_DIRECTORY "${shader_air_root}" "${shader_library_root}")

file(GLOB shader_dependencies
  "${shader_root}/*.h"
  "${shader_root}/*ColorBlend.metal"
  "${shader_root}/*AlphaBlend.metal"
)

function(add_metal_library source output_name)
  set(air_file "${shader_air_root}/${output_name}.air")
  set(library_file "${shader_library_root}/${output_name}.metallib")
  add_custom_command(
    OUTPUT "${library_file}"
    COMMAND /usr/bin/xcrun -sdk macosx metal
      -I "${shader_root}"
      ${ARGN}
      -c "${source}"
      -o "${air_file}"
    COMMAND /usr/bin/xcrun -sdk macosx metallib
      "${air_file}"
      -o "${library_file}"
    DEPENDS "${source}" ${shader_dependencies}
    VERBATIM
  )
  set(cubism_shader_outputs ${cubism_shader_outputs} "${library_file}" PARENT_SCOPE)
endfunction()

foreach(shader_name MetalShaders VertShaderSrcBlend VertShaderSrcMaskedBlend)
  add_metal_library("${shader_root}/${shader_name}.metal" "${shader_name}")
endforeach()

set(color_blend_names
  Normal Add AddGlow Darken Multiply ColorBurn LinearBurn Lighten
  Screen ColorDodge Overlay SoftLight HardLight LinearLight Hue Color
)
set(alpha_blend_names Over Atop Out ConjointOver DisjointOver)
set(blend_shader_names
  FragShaderSrcBlend
  FragShaderSrcMaskBlend
  FragShaderSrcMaskInvertedBlend
  FragShaderSrcPremultipliedAlphaBlend
  FragShaderSrcMaskPremultipliedAlphaBlend
  FragShaderSrcMaskInvertedPremultipliedAlphaBlend
)

foreach(color_index RANGE 0 15)
  list(GET color_blend_names ${color_index} color_name)
  foreach(alpha_index RANGE 0 4)
    if(color_index EQUAL 0 AND alpha_index EQUAL 0)
      continue()
    endif()
    list(GET alpha_blend_names ${alpha_index} alpha_name)
    foreach(shader_name ${blend_shader_names})
      add_metal_library(
        "${shader_root}/${shader_name}.metal"
        "${shader_name}${color_name}${alpha_name}"
        -D "CSM_COLOR_BLEND_MODE=${color_index}"
        -D "CSM_ALPHA_BLEND_MODE=${alpha_index}"
      )
    endforeach()
  endforeach()
endforeach()

add_custom_target(BongoCubismShaders ALL DEPENDS ${cubism_shader_outputs})
