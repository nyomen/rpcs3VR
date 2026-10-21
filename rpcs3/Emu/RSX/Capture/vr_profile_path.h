#pragma once

#include <cstdlib>
#include <string>

#include "Utilities/File.h"

namespace rsx::vr
{
    inline std::string vr_profiles_dir()
    {
        const char* appdir = std::getenv("APPDIR");

        if (appdir && *appdir)
            return std::string(appdir) + "/usr/bin/vr_profiles/";

        return fs::get_executable_dir() + "vr_profiles/";
    }
}
