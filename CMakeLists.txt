project(pro_tmpl_stm32f10x)
cmake_minimum_required(VERSION 3.3)
enable_language(ASM)

set(BUILD_MODE DEBUG)
#在Clion中Settings>Build>Cmake的Cmake options加入下面一行（自行修正路径），不包含#符号。
#-DTOOLCHAIN_DIR="C:\Program Files (x86)\GNU Tools ARM Embedded\6 2017-q2-update" -DCMAKE_TOOLCHAIN_FILE="toolchain-arm-eabi-gcc.cmake"

set(USER_C_FLAGS "-mcpu=cortex-m3 -mthumb -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections -ffreestanding -fno-move-loop-invariants -Wall")
set(USER_CXX_FLAGS "-std=c++11 -fabi-version=0 -fno-exceptions -fno-rtti -fno-use-cxa-atexit -fno-threadsafe-statics")

#下面可选 -DSTM32F10X_MD -DSTM32F10X_HD等。一般选高点的_HD也不影响运行。
set(USER_C_DEFINES
        "-DARM_MATH_CM3 \
    -DUSE_FULL_ASSERT \
    -DTRACE \
    -DOS_USE_TRACE_SEMIHOSTING_STDOUT \
    -DSTM32F10X_MD \
    -DUSE_STDPERIPH_DRIVER \
    -DHSE_VALUE=8000000"
        )

if (BUILD_MODE STREQUAL "DEBUG")
    set(USER_C_FLAGS "${USER_C_FLAGS} -Og -g3")
    set(USER_C_DEFINES "${USER_C_DEFINES} -DDEBUG")
else ()
    set(USER_C_FLAGS "${USER_C_FLAGS} -O3")
endif ()

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${USER_C_FLAGS} ${USER_C_DEFINES}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${USER_C_FLAGS} ${USER_CXX_FLAGS} ${USER_C_DEFINES}")


include_directories(
        ${TOOLCHAIN_DIR}/arm-none-eabi/include
        ${TOOLCHAIN_DIR}/arm-none-eabi/include/c++/6.3.1
        ${TOOLCHAIN_DIR}/arm-none-eabi/include/c++/6.3.1/arm-none-eabi/thumb/v7-m
        ${TOOLCHAIN_DIR}/arm-none-eabi/include/c++/6.3.1/backward
        ${TOOLCHAIN_DIR}/lib/gcc/arm-none-eabi/6.3.1/include
        ${TOOLCHAIN_DIR}/lib/gcc/arm-none-eabi/6.3.1/include-fixed
)
include_directories(
        #STM32固件库
        system/include
        system/include/cmsis
        system/include/stm32f1-stdperiph
        #ALIENTEK开发板的代码库
        board/ALIENTEK/System/delay
        board/ALIENTEK/System/sys
        board/ALIENTEK/System/usart
        #ALIENTEK开发板的模块代码库
        board/ALIENTEK/MiniSTM32Board/LED
        board/ALIENTEK/MiniSTM32Board/KEY
        #自己的include
        user/include
)

file(GLOB_RECURSE C_FILES
        #stm32固件库
        system/*.c system/*.cpp
        #ALIENTEK开发板的代码库
        board/*.c board/*.cpp
        #自己的
        user/*.c user/*.cpp
        )

set(SOURCE_FILES ${C_FILES})

set(CMAKE_EXE_LINKER_FLAGS
        "${CMAKE_EXE_LINKER_FLAGS} -L\"${PROJECT_SOURCE_DIR}/ldscripts\" -T libs.ld -T mem.ld -T sections.ld -fmessage-length=0 -fsigned-char -ffreestanding -nostartfiles -specs=nano.specs -Xlinker --gc-sections -Wl,-Map=${PROJECT_NAME}.map")
#TODO 似乎直接Run的可以不生成elf吧。
add_executable(${PROJECT_NAME}.elf ${SOURCE_FILES})
set(HEX_FILE ${CMAKE_BINARY_DIR}/${PROJECT_NAME}.hex)
set(BIN_FILE ${CMAKE_BINARY_DIR}/${PROJECT_NAME}.bin)
add_custom_command(TARGET ${PROJECT_NAME}.elf POST_BUILD
        COMMAND ${CMAKE_OBJCOPY} -Oihex $<TARGET_FILE:${PROJECT_NAME}.elf> ${HEX_FILE}
        COMMAND ${CMAKE_OBJCOPY} -Obinary $<TARGET_FILE:${PROJECT_NAME}.elf> ${BIN_FILE}
        )
#TODO 找直接刷hex到串口的方法
#TODO 1 OpenOCD关了重启与expect通信不上的原因。