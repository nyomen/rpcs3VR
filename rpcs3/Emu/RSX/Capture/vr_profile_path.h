#pragma once

#include <string>

#include "Utilities/File.h"

namespace rsx::vr
{
    inline std::string vr_profiles_dir()
    {
        return fs::get_appimage_usr_bin_dir() + "vr_profiles/";
    }
}
