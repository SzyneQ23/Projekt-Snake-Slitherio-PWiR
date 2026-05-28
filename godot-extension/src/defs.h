#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#if !defined(GDE_EXPORT)
#if defined(_WIN32)
#define GDE_EXPORT __declspec(dllexport)
#elif defined(__GNUC__)
#define GDE_EXPORT __attribute__((visibility("default")))
#else
#define GDE_EXPORT
#endif
#endif // ! GDE_EXPORT

// The sizes can be obtained from the extension_api.json file.
#ifdef BUILD_32
#define STRING_NAME_SIZE 4
#else
#define STRING_NAME_SIZE 8
#endif

// Types.

typedef struct
{
    uint8_t data[STRING_NAME_SIZE];
} StringName;
