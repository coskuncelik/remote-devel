cmake_minimum_required(VERSION 3.22)

if(NOT CMAKE_TOOLCHAIN_FILE)
  set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/cmake/arm-none-eabi.cmake)
endif()

project(blinky C ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)   # for clangd

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Debug)
endif()

set(DRIVERS ${CMAKE_CURRENT_SOURCE_DIR}/Drivers)
set(CMSIS_DEV ${DRIVERS}/CMSIS/Device/ST/STM32F4xx)
set(HAL ${DRIVERS}/STM32F4xx_HAL_Driver)

if(NOT EXISTS ${HAL}/Src/stm32f4xx_hal.c)
  message(FATAL_ERROR "ST drivers missing. Run ./fetch_drivers.sh first.")
endif()

add_executable(${PROJECT_NAME}
  Core/Src/main.c
  Core/Src/stm32f4xx_it.c
  Core/Src/syscalls.c
  ${CMSIS_DEV}/Source/Templates/system_stm32f4xx.c
  ${CMSIS_DEV}/Source/Templates/gcc/startup_stm32f411xe.s
  ${HAL}/Src/stm32f4xx_hal.c
  ${HAL}/Src/stm32f4xx_hal_cortex.c
  ${HAL}/Src/stm32f4xx_hal_dma.c
  ${HAL}/Src/stm32f4xx_hal_exti.c
  ${HAL}/Src/stm32f4xx_hal_flash.c
  ${HAL}/Src/stm32f4xx_hal_flash_ex.c
  ${HAL}/Src/stm32f4xx_hal_gpio.c
  ${HAL}/Src/stm32f4xx_hal_pwr.c
  ${HAL}/Src/stm32f4xx_hal_pwr_ex.c
  ${HAL}/Src/stm32f4xx_hal_rcc.c
  ${HAL}/Src/stm32f4xx_hal_rcc_ex.c
)

set_target_properties(${PROJECT_NAME} PROPERTIES SUFFIX ".elf")

# Vendor code: don't flood the build log with ST's unused-parameter warnings.
file(GLOB VENDOR_SOURCES ${HAL}/Src/*.c ${CMSIS_DEV}/Source/Templates/*.c)
set_source_files_properties(${VENDOR_SOURCES} PROPERTIES COMPILE_OPTIONS "-Wno-unused-parameter")

target_compile_definitions(${PROJECT_NAME} PRIVATE
  STM32F411xE
  USE_HAL_DRIVER
)

target_include_directories(${PROJECT_NAME} PRIVATE
  Core/Inc
  ${CMSIS_DEV}/Include
  ${DRIVERS}/CMSIS/Include
  ${HAL}/Inc
)

set(LINKER_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/STM32F411RETX_FLASH.ld)
target_link_options(${PROJECT_NAME} PRIVATE
  -T${LINKER_SCRIPT}
  -Wl,-Map=${PROJECT_NAME}.map,--cref
)
set_target_properties(${PROJECT_NAME} PROPERTIES LINK_DEPENDS ${LINKER_SCRIPT})

# Produce .hex/.bin next to the .elf and print the size.
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
  COMMAND ${CMAKE_OBJCOPY} -O ihex   $<TARGET_FILE:${PROJECT_NAME}> ${PROJECT_NAME}.hex
  COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:${PROJECT_NAME}> ${PROJECT_NAME}.bin
  COMMAND ${CMAKE_SIZE} $<TARGET_FILE:${PROJECT_NAME}>
  BYPRODUCTS ${PROJECT_NAME}.hex ${PROJECT_NAME}.bin ${PROJECT_NAME}.map
  COMMENT "Creating ${PROJECT_NAME}.hex / .bin"
)
