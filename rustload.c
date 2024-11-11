#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>

__attribute__((constructor))
int app_start() {
    void *handle = dlopen("/data/app/MAINAPP/lib/rustapp.so", RTLD_LAZY);
    
    typedef void (*load_func)();
    load_func rust_load = (load_func)dlsym(handle, "rust_load");

    rust_load();

    dlclose(handle);

    return 0;
}

