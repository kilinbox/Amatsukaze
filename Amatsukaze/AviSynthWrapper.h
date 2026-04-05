#pragma once

/**
* AviSynth Wrapper
* Copyright (c) 2017-2019 Nekopanda
*
* This software is released under the MIT License.
* http://opensource.org/licenses/mit-license.php
*/

#ifdef _stricmp
#undef _stricmp
#endif
RGY_DISABLE_WARNING_PUSH
RGY_DISABLE_WARNING_STR("-Wsign-compare")
#ifndef _WIN32
// macOS/Linux: -fvisibility=hidden ビルドでも AvisynthError の RTTI を
// デフォルト可視性でエクスポートし、ライブラリ間の RTTI ミスマッチを防ぐ
#pragma GCC visibility push(default)
#endif
#include "avisynth.h"
#pragma comment(lib, "avisynth.lib")
#ifndef _WIN32
#pragma GCC visibility pop
#endif
RGY_DISABLE_WARNING_POP

#define AVISYNTH_NEO (1)
#define AVISYNTH_PLUS (2) 

#if defined(_WIN32) || defined(_WIN64)
#define AVISYNTH_MODE AVISYNTH_NEO
#else
#define AVISYNTH_MODE AVISYNTH_PLUS
#endif

#if AVISYNTH_MODE == AVISYNTH_PLUS
#define GetProperty GetEnvProperty
#define CopyFrameProps copyFrameProps
#endif
