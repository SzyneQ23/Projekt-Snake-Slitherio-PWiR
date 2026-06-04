#pragma once

#include "defs.h"

#include "gdextension_interface.h"

void initialize_gdexample_module(void *p_userdata, GDExtensionInitializationLevel p_level);
void deinitialize_gdexample_module(void *p_userdata, GDExtensionInitializationLevel p_level);
GDExtensionBool GDE_EXPORT gdexample_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization);
