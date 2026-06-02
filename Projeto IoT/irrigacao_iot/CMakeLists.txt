# Generated Cmake Pico project file

cmake_minimum_required(VERSION 3.13)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Initialise pico_sdk from installed location
# (note this can come from environment, CMake cache etc)

# == DO NOT EDIT THE FOLLOWING LINES for the Raspberry Pi Pico VS Code Extension to work ==
if(WIN32)
    set(USERHOME $ENV{USERPROFILE})
else()
    set(USERHOME $ENV{HOME})
endif()
set(sdkVersion 1.5.1)
set(toolchainVersion 13_2_Rel1)
set(picotoolVersion 2.0.0)
set(picoVscode ${USERHOME}/.pico-sdk/cmake/pico-vscode.cmake)
if (EXISTS ${picoVscode})
    include(${picoVscode})
endif()
# ====================================================================================
set(PICO_BOARD pico_w CACHE STRING "Board type")

# Pull in Raspberry Pi Pico SDK (must be before project)
include(pico_sdk_import.cmake)

project(irrigacao_iot C CXX ASM)

# Initialise the Raspberry Pi Pico SDK
pico_sdk_init()

# Add executable. Default name is the project name, version 0.1

add_executable(irrigacao_iot irrigacao_iot.c
    src/MQTTConnectClient.c
    src/MQTTDeserializePublish.c
    src/MQTTFormat.c
    src/MQTTPacket.c
    src/MQTTSerializePublish.c
    src/MQTTSubscribeClient.c
    src/MQTTUnsubscribeClient.c
    )

pico_set_program_name(irrigacao_iot "irrigacao_iot")
pico_set_program_version(irrigacao_iot "0.1")

# Modify the below lines to enable/disable output over UART/USB
pico_enable_stdio_uart(irrigacao_iot 1)
pico_enable_stdio_usb(irrigacao_iot 1)

# Add the standard library to the build
target_link_libraries(irrigacao_iot
        pico_stdlib)

# Add the standard include files to the build
target_include_directories(irrigacao_iot PRIVATE
        ${CMAKE_CURRENT_LIST_DIR}
        src
)

# Add any user requested libraries
target_link_libraries(irrigacao_iot 
        pico_cyw43_arch_lwip_poll
        pico_lwip_mbedtls
        pico_mbedtls
        pico_lwip_sntp
        )

pico_add_extra_outputs(irrigacao_iot)